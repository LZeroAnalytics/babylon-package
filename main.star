input_parser = import_module("./src/package_io/input_parser.star")
genesis_generator = import_module("./src/genesis-generator/genesis_generator.star")
bitcoin_launcher = import_module("./src/bitcoin/bitcoin_launcher.star")
network_launcher = import_module("./src/network_launcher/network_launcher.star")
staking_backend = import_module("./src/staking_backend/staking_backend_launcher.star")
faucet = import_module("./src/faucet/faucet_launcher.star")

def run(plan, args):
    parsed_args = input_parser.input_parser(args)

    btc_info = bitcoin_launcher.deploy(plan, parsed_args)

    genesis_files = genesis_generator.generate_genesis_files(plan, parsed_args)

    babylon_networks = network_launcher.launch_network(plan, genesis_files, parsed_args)

    backend_args = {
        "btc_rpc": btc_info["rpc_url"],
        "babylon_networks": babylon_networks,
        "mongo_uri": "mongodb://mongodb:27017"
    }
    backend_info = staking_backend.deploy(plan, backend_args, parsed_args)

    service_launchers = {
        "faucet": faucet.launch_faucet
    }

    for chain in parsed_args["chains"]:
        chain_name = chain["name"]
        chain_id = chain["chain_id"]
        additional_services = chain.get("additional_services", [])

        node_info = babylon_networks[chain_name]
        node_names = []
        for node in node_info:
            node_names.append(node["name"])

        # Skip waiting for first block since we're using placeholder services
        plan.print("Skipping block wait for placeholder Babylon node: " + chain_name)

        for service in service_launchers:
            if service in additional_services:
                plan.print("Launching {} for chain {}".format(service, chain_name))
                if service == "faucet":
                    faucet_mnemonic = genesis_files[chain_name]["mnemonics"][-1]
                    transfer_amount = chain["faucet"]["transfer_amount"]
                    service_launchers[service](plan, chain_name, chain_id, faucet_mnemonic, transfer_amount, btc_info)



    plan.print("Babylon package deployed successfully!")
    plan.print("Bitcoin Signet RPC: {}".format(btc_info["rpc_url"]))
    plan.print("Staking API: http://localhost:8080")
    plan.print("Genesis files: {}".format(genesis_files))
