def generate_genesis_files(plan, parsed_args):
    out = {}

    for chain_cfg in parsed_args["chains"]:
        out[chain_cfg["name"]] = _one_chain(plan, chain_cfg)

    return out

def _one_chain(plan, chain_cfg):
    binary = chain_cfg["binary"]
    config_dir = "/root/.babylond/config"
    chain_id = chain_cfg["chain_id"]

    total_count = 0
    account_balances = []
    bond_amounts = []

    for participant in chain_cfg["participants"]:
        total_count += participant["count"]
        for _ in range(participant["count"]):
            account_balances.append("{}".format(participant["account_balance"]))
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

    _add_balances(plan, binary, addresses, account_balances, chain_cfg["denom"]["name"])

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

    gen_file = plan.render_templates(
        config={"genesis.json": struct(
            template=read_file("templates/genesis_babylon.json.tmpl"),
            data=genesis_data,
        )},
        name="{}-genesis-render".format(chain_cfg["name"]),
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
            files={},
        )
    )
    plan.exec("genesis-service", ExecRecipe(command=["mkdir", "-p", config_dir]))

def _generate_validator_keys(plan, binary, chain_id, count):
    m, addr, secp, ed, cons = [], [], [], [], []

    for i in range(count):
        kr_flags = "--keyring-backend test"
        # Placeholder for babylond key generation since babylond binary is not available
        placeholder_output = '{{"address":"bbn1placeholder{}","mnemonic":"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"}}'.format(i)
        cmd = "echo '{}'".format(placeholder_output)
        plan.print(cmd)
        res = plan.exec("genesis-service", ExecRecipe(
            command=["/bin/sh", "-c", cmd],
            extract={"addr": "fromjson | .address", "mnemonic": "fromjson | .mnemonic"}
        ))
        addr.append(res["extract.addr"].replace("\n", ""))
        m.append(res["extract.mnemonic"].replace("\n", ""))

        babylond_flags = "--chain-id {}".format(chain_id)
        _init_empty_chain(plan, binary, res["extract.mnemonic"].replace("\n", ""), babylond_flags)

        # Placeholder for public key generation since babylond binary is not available
        placeholder_secp = "bbn1placeholder{}secp".format(i)
        placeholder_cons = "bbn1placeholder{}cons".format(i)
        placeholder_ed = "bbn1placeholder{}ed".format(i)
        
        secp.append(placeholder_secp)
        cons.append(placeholder_cons)
        ed.append(placeholder_ed)

    # Placeholder for faucet key generation
    faucet_output = '{"address":"bbn1faucetplaceholder","mnemonic":"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"}'
    res = plan.exec("genesis-service", ExecRecipe(
        command=["/bin/sh", "-c", "echo '{}'".format(faucet_output)],
        extract={"addr": "fromjson | .address", "mnemonic": "fromjson | .mnemonic"}
    ))
    addr.append(res["extract.addr"].replace("\n", ""))
    m.append(res["extract.mnemonic"].replace("\n", ""))

    return m, addr, secp, ed, cons

def _init_empty_chain(plan, binary, mnemonic, babylond_flags):
    # Placeholder for chain initialization since babylond binary is not available
    cmd = "echo 'Placeholder: chain initialized with mnemonic'"
    plan.print(cmd)
    plan.exec("genesis-service", ExecRecipe(command=["/bin/sh", "-c", cmd]))

def _add_balances(plan, binary, addresses, amounts, denom):
    for a, amt in zip(addresses, amounts):
        # Placeholder for adding genesis accounts since babylond binary is not available
        cmd = "echo 'Placeholder: added {} {} to address {}'".format(amt, denom, a)
        plan.print(cmd)
        plan.exec("genesis-service", ExecRecipe(
            command=["/bin/sh", "-c", cmd]
        ))

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
