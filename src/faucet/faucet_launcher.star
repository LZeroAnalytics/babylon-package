def launch_faucet(plan, chain_name, chain_id, faucet_mnemonic, transfer_amount, btc_info):
    plan.print("Launching faucet for chain {}".format(chain_name))
    
    faucet_script = plan.render_templates(
        config={
            "faucet.py": struct(
                template=read_file("templates/faucet.py.tmpl"),
                data={
                    "ChainName": chain_name,
                    "ChainID": chain_id,
                    "FaucetMnemonic": faucet_mnemonic,
                    "TransferAmount": transfer_amount,
                    "BTCRPCUrl": btc_info["rpc_url"],
                    "BTCRPCUser": btc_info["rpc_user"],
                    "BTCRPCPassword": btc_info["rpc_password"]
                }
            )
        },
        name="{}-faucet-script".format(chain_name)
    )
    
    faucet_service = plan.add_service(
        name="{}-faucet".format(chain_name),
        config=ServiceConfig(
            image="python:3.9-slim",
            ports={
                "http": PortSpec(number=5000, transport_protocol="TCP", wait="30s")
            },
            files={
                "/app": faucet_script
            },
            cmd=[
                "sh", "-c",
                "cd /app && pip install flask requests && python faucet.py"
            ],
            env_vars={
                "CHAIN_NAME": chain_name,
                "CHAIN_ID": chain_id,
                "FAUCET_MNEMONIC": faucet_mnemonic,
                "TRANSFER_AMOUNT": str(transfer_amount)
            }
        )
    )
    
    plan.print("Faucet deployed for chain {} on port 5000".format(chain_name))
    
    return faucet_service
