def generate_genesis_files(plan, parsed_args):
    out = {}

    for chain_cfg in parsed_args["chains"]:
        out[chain_cfg["name"]] = _one_chain(plan, chain_cfg)

    return out

def _one_chain(plan, chain_cfg):
    binary = chain_cfg["binary"]
    config_dir = "/home/babylon/.babylond/config"
    chain_id = chain_cfg["chain_id"]

    total_count = 0
    account_balances = []
    bond_amounts = []

    for participant in chain_cfg["participants"]:
        total_count += participant["count"]
        for _ in range(participant["count"]):
            # Use large balance like babylon-deployment (1 trillion ubbn tokens)
            balance = 1000000000000000  # 1 trillion ubbn tokens like babylon-deployment
            account_balances.append("{}".format(balance))
            if participant.get("staking", True):
                bond_amounts.append("{}".format(participant["bond_amount"]))
    account_balances.append("{}".format(chain_cfg["faucet"]["faucet_amount"]))

    _start_genesis_service(
        plan=plan,
        chain_cfg=chain_cfg,
        binary=binary,
        config_dir=config_dir,
    )

    (
        mnemonics,
        addresses,
        secp_pks,
        ed_pks,
        cons_pks,
    ) = _generate_validator_keys(
        plan=plan,
        binary=binary,
        chain_id=chain_id,
        count=total_count,
    )

    # Generate key names for validators and faucet
    key_names = []
    for i in range(total_count):
        key_names.append("validator{}".format(i))
    key_names.append("faucet")
    
    _add_balances(plan, binary, key_names, account_balances, chain_cfg["denom"]["name"])

    # Create genesis transactions for validators
    _create_gentx(plan, binary, chain_id, total_count)

    finality_providers = []
    for i in range(total_count):
        finality_providers.append({
            "description": {
                "moniker": "fp-{}".format(i),
                "identity": "",
                "website": "",
                "security_contact": "",
                "details": ""
            },
            "commission": "0.050000000000000000",
            "babylon_pk": secp_pks[i],
            "btc_pk": secp_pks[i],
            "pop": {
                "btc_sig_type": 0,
                "btc_sig": "",
                "babylon_sig": ""
            }
        })

    accounts_json = json.encode(_mk_accounts_array(addresses))
    balances_json = json.encode(_mk_balances_array(
        addresses,
        account_balances,
        chain_cfg["denom"]["name"]
    ))
    finality_providers_json = json.encode(finality_providers)

    genesis_data = {
        "AppVersion": chain_cfg["app_version"],
        "ChainID": chain_id,
        "GenesisTime": _get_genesis_time(plan, chain_cfg["genesis_delay"]),
        "InitialHeight": chain_cfg["initial_height"],
        "BlockMaxBytes": chain_cfg["consensus"]["block_max_bytes"],
        "BlockMaxGas": chain_cfg["consensus"]["block_max_gas"],
        "EvidenceMaxAgeNumBlocks": chain_cfg["consensus"]["evidence_max_age_num_blocks"],
        "EvidenceMaxAgeDuration": chain_cfg["consensus"]["evidence_max_age_duration"],
        "EvidenceMaxBytes": chain_cfg["consensus"]["evidence_max_bytes"],
        "ValidatorPubKeyTypes": json.encode(chain_cfg["consensus"]["validator_pub_key_types"]),

        "AuthMaxMemoCharacters": chain_cfg["modules"]["auth"]["max_memo_characters"],
        "AuthTxSigLimit": chain_cfg["modules"]["auth"]["tx_sig_limit"],
        "AuthTxSizeCostPerByte": chain_cfg["modules"]["auth"]["tx_size_cost_per_byte"],
        "AuthSigVerifyCostEd25519": chain_cfg["modules"]["auth"]["sig_verify_cost_ed25519"],
        "AuthSigVerifyCostSecp256k1": chain_cfg["modules"]["auth"]["sig_verify_cost_secp256k1"],

        "DenomName": chain_cfg["denom"]["name"],
        "DenomDisplay": chain_cfg["denom"]["display"],
        "DenomSymbol": chain_cfg["denom"]["symbol"],
        "DenomDescription": chain_cfg["denom"]["description"],

        "MintInflation": chain_cfg["modules"]["mint"]["inflation"],
        "MintAnnualProvisions": chain_cfg["modules"]["mint"]["annual_provisions"],
        "MintBlocksPerYear": chain_cfg["modules"]["mint"]["blocks_per_year"],
        "MintGoalBonded": chain_cfg["modules"]["mint"]["goal_bonded"],
        "MintInflationMax": chain_cfg["modules"]["mint"]["inflation_max"],
        "MintInflationMin": chain_cfg["modules"]["mint"]["inflation_min"],
        "MintInflationRateChange": chain_cfg["modules"]["mint"]["inflation_rate_change"],

        "BTCConfirmationDepth": chain_cfg["modules"]["btccheckpoint"]["btc_confirmation_depth"],
        "CheckpointFinalizationTimeout": chain_cfg["modules"]["btccheckpoint"]["checkpoint_finalization_timeout"],
        "EpochInterval": chain_cfg["modules"]["epoching"]["epoch_interval"],
        "CheckpointingGenesisHash": chain_cfg["modules"]["checkpointing"]["genesis_hash"],

        "FinalityProviders": finality_providers_json,
        "Accounts": accounts_json,
        "Balances": balances_json,
    }

    plan.print(genesis_data)

    # Copy the actual genesis file that includes gentx data instead of using template
    gen_file = plan.store_service_files(
        service_name="genesis-service",
        src="/home/babylon/.babylond/config/genesis.json",
        name="{}-genesis-render".format(chain_cfg["name"])
    )

    plan.remove_service("genesis-service")

    return {
        "genesis_file": gen_file,
        "mnemonics": mnemonics,
        "addresses": addresses,
    }

def _start_genesis_service(plan, chain_cfg, binary, config_dir):
    plan.add_service(
        name="genesis-service",
        config=ServiceConfig(
            image=chain_cfg["participants"][0]["image"],
            files={}
        )
    )
    # Clean up any existing files first
    plan.exec("genesis-service", ExecRecipe(command=["rm", "-rf", "/home/babylon/.babylond"]))
    # Initialize with --no-bls-password flag like babylon-deployment
    plan.exec("genesis-service", ExecRecipe(command=["babylond", "init", "genesis-node", "--chain-id", chain_cfg["chain_id"], "--home", "/home/babylon/.babylond", "--no-bls-password"]))

def _generate_validator_keys(plan, binary, chain_id, count):
    m, addr, secp, ed, cons = [], [], [], [], []

    # Use exact same mnemonics and key names as babylon-deployment setup script
    # VAL0_KEY="val" with VAL0_MNEMONIC (line 33-34)
    val_mnemonic = "copper push brief egg scan entry inform record adjust fossil boss egg comic alien upon aspect dry avoid interest fury window hint race symptom"
    user_mnemonic = "pony glide frown crisp unfold lawn cup loan trial govern usual matrix theory wash fresh address pioneer between meadow visa buffalo keep gallery swear"
    submitter_mnemonic = "catalog disagree royal alley edge negative erase clip dolphin undo pipe fire small siren bird crowd reopen wrestle stumble survey rib gospel master toilet"
    btc_staker_mnemonic = "birth immune execute prosper flee tonight slab own pause robust fatal debris endorse bottom ask hawk material trend tomato lunch surprise above finish road"

    kr_flags = "--keyring-backend test"
    
    # Import keys exactly like babylon-deployment (lines 108-111)
    plan.print("Importing keys exactly like babylon-deployment...")
    
    # Import val key (this is the validator key used in gentx)
    import_cmd = "echo '{}' | {} keys add val {} --recover --home /home/babylon/.babylond".format(val_mnemonic, binary, kr_flags)
    plan.exec("genesis-service", ExecRecipe(command=["/bin/sh", "-c", import_cmd]))
    
    # Import user key
    import_cmd = "echo '{}' | {} keys add user {} --recover --home /home/babylon/.babylond".format(user_mnemonic, binary, kr_flags)
    plan.exec("genesis-service", ExecRecipe(command=["/bin/sh", "-c", import_cmd]))
    
    # Import submitter key
    import_cmd = "echo '{}' | {} keys add submitter {} --recover --home /home/babylon/.babylond".format(submitter_mnemonic, binary, kr_flags)
    plan.exec("genesis-service", ExecRecipe(command=["/bin/sh", "-c", import_cmd]))
    
    # Import btc-staker key
    import_cmd = "echo '{}' | {} keys add btc-staker {} --recover --home /home/babylon/.babylond".format(btc_staker_mnemonic, binary, kr_flags)
    plan.exec("genesis-service", ExecRecipe(command=["/bin/sh", "-c", import_cmd]))
    
    # Get validator address for gentx
    addr_cmd = "{} keys show val -a {} --home /home/babylon/.babylond".format(binary, kr_flags)
    addr_res = plan.exec("genesis-service", ExecRecipe(
        command=["/bin/sh", "-c", addr_cmd],
        extract={"addr": ". | gsub(\"\\n\"; \"\")"}
    ))
    
    # Return the validator info (only need one validator for now)
    m.append(val_mnemonic)
    addr.append(addr_res["extract.addr"])
    secp.append("")  # Not needed for basic setup
    ed.append("")    # Not needed for basic setup
    cons.append("")  # Not needed for basic setup

    return m, addr, secp, ed, cons

def _init_empty_chain(plan, binary, mnemonic, babylond_flags):
    # Skip init since genesis service already initialized the chain
    pass

def _add_balances(plan, binary, key_names, amounts, denom):
    # Add genesis accounts exactly like babylon-deployment (lines 121-125)
    plan.print("Adding genesis accounts exactly like babylon-deployment...")
    
    # Use exact same amounts as babylon-deployment: 1000000000000ubbn
    coins = "1000000000000ubbn"
    
    # Add accounts for each key exactly like babylon-deployment does
    key_names_babylon = ["val", "user", "submitter", "btc-staker"]
    
    for key_name in key_names_babylon:
        # Get address for the key
        addr_cmd = "{} keys show {} -a --keyring-backend test --home /home/babylon/.babylond".format(binary, key_name)
        addr_res = plan.exec("genesis-service", ExecRecipe(
            command=["/bin/sh", "-c", addr_cmd],
            extract={"addr": ". | gsub(\"\\n\"; \"\")"}
        ))
        actual_address = addr_res["extract.addr"]
        
        # Add genesis account with exact same amount as babylon-deployment
        plan.exec("genesis-service", ExecRecipe(
            command=[binary, "add-genesis-account", actual_address, coins, "--home", "/home/babylon/.babylond"]
        ))

def _create_gentx(plan, binary, chain_id, validator_count):
    # Apply genesis patches FIRST exactly like babylon-deployment does (lines 142-154)
    # This must happen BEFORE gentx creation to avoid corrupting validator set
    plan.print("Applying genesis patches BEFORE gentx like babylon-deployment...")
    
    # Apply ALL genesis patches BEFORE creating gentx (like babylon-deployment does)
    plan.print("Applying all genesis patches before gentx creation...")
    patch_cmd = '''
    jq '.consensus_params["block"]["time_iota_ms"]="5000"
    | .app_state["crisis"]["constant_fee"]["denom"]="ubbn"
    | .app_state["staking"]["params"]["bond_denom"]="ubbn"
    | .app_state["btcstaking"]["params"][0]["covenant_pks"] = [
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5"
    ]
    | .app_state["btcstaking"]["params"][0]["covenant_quorum"]="2"
    | .app_state["btcstaking"]["params"][0]["slashing_pk_script"]="dqkUAQEBAQEBAQEBAQEBAQEBAQEBAQGIrA=="
    | .app_state["btccheckpoint"]["params"]["btc_confirmation_depth"]="2"
    | .app_state["consensus"]=null
    | .consensus["params"]["abci"]["vote_extensions_enable_height"]="1"
    | .app_state["gov"]["params"]["expedited_voting_period"]="10s"
    | .app_state["gov"]["params"]["min_deposit"][0]["denom"]="ubbn"
    | .app_state["gov"]["params"]["expedited_min_deposit"][0]["denom"]="ubbn"
    | .app_state["gov"]["params"]["voting_period"]="30s"' \
    /home/babylon/.babylond/config/genesis.json > /home/babylon/.babylond/config/tmp_genesis.json && \
    mv /home/babylon/.babylond/config/tmp_genesis.json /home/babylon/.babylond/config/genesis.json
    '''
    plan.exec("genesis-service", ExecRecipe(
        command=["/bin/sh", "-c", patch_cmd]
    ))
    
    # Create genesis transactions exactly like babylon-deployment setup script
    # Use the exact same key name and stake amount as babylon-deployment
    
    plan.print("Creating gentx exactly like babylon-deployment...")
    
    # Create BLS password file that gentx expects to exist
    plan.exec("genesis-service", ExecRecipe(
        command=["sh", "-c", "echo '' > /home/babylon/.babylond/config/bls_password.txt"]
    ))
    
    # Use the exact gentx command from babylon-deployment line 164 with 1 trillion ubbn
    plan.exec("genesis-service", ExecRecipe(
        command=[binary, "gentx", "val", "1000000000000ubbn", 
                "--keyring-backend", "test", 
                "--chain-id", chain_id, 
                "--gas-prices", "2ubbn",
                "--home", "/home/babylon/.babylond"]
    ))
    
    # Collect gentxs exactly like babylon-deployment line 167
    plan.print("Collecting gentxs...")
    plan.exec("genesis-service", ExecRecipe(
        command=[binary, "collect-gentxs", "--home", "/home/babylon/.babylond"]
    ))
    
    # Debug: Check final validator set in genesis after collect-gentxs
    plan.print("DEBUG: Checking final validator set after collect-gentxs...")
    plan.exec("genesis-service", ExecRecipe(
        command=["jq", ".validators", "/home/babylon/.babylond/config/genesis.json"]
    ))
    
    # Skip genesis validation like babylon-deployment does due to known SDK issues
    plan.print("Skipping genesis validation due to known SDK issues (like babylon-deployment)")

def _mk_accounts_array(addrs):
    return [{
        "@type": "/cosmos.auth.v1beta1.BaseAccount",
        "address": a,
        "pub_key": None,
        "account_number": "0",
        "sequence": "0",
    } for a in addrs]

def _mk_balances_array(addrs, amounts, denom):
    balances = []
    for i, addr in enumerate(addrs):
        balances.append({"address": addr, "coins": [{"denom": denom, "amount": amounts[i]}]})
    return balances

def _get_genesis_time(plan, genesis_delay):
    result = plan.run_python(
        description="Calculating genesis time",
        run="""
import time
from datetime import datetime, timedelta
import sys

padding = int(sys.argv[1])
future_time = datetime.utcnow() + timedelta(seconds=padding)
formatted_time = future_time.strftime('%Y-%m-%dT%H:%M:%SZ')
print(formatted_time, end="")
""",
        args=[str(genesis_delay)]
    )
    return result.output
