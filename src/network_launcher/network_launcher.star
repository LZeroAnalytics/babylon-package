def launch_network(plan, genesis_files, parsed_args):
    networks = {}
    for chain in parsed_args["chains"]:
        chain_name = chain["name"]
        chain_id = chain["chain_id"]
        binary = chain["binary"]
        config_folder = "/home/babylon/.babylond/config"
        babylond_args = ""
        
        genesis_file = genesis_files[chain_name]["genesis_file"]
        mnemonics = genesis_files[chain_name]["mnemonics"]
        
        node_info = start_network(plan, chain, binary, chain_id, config_folder, babylond_args, genesis_file, mnemonics)
        networks[chain_name] = node_info
    
    return networks

def start_network(plan, chain, binary, chain_id, config_folder, babylond_args, genesis_file, mnemonics):
    chain_name = chain["name"]
    participants = chain["participants"]
    
    node_info = []
    node_counter = 1
    first_node_id = ""
    first_node_ip = ""
    
    for participant in participants:
        count = participant["count"]
        for i in range(count):
            node_name = "{}-node-{}".format(chain_name, node_counter)
            mnemonic = mnemonics[node_counter - 1]
            
            is_first_node = node_counter == 1
            
            if is_first_node:
                first_node_id, first_node_ip = start_node(
                    plan, 
                    node_name, 
                    participant, 
                    binary,
                    chain_id,
                    babylond_args, 
                    config_folder, 
                    genesis_file, 
                    mnemonic,
                    True, 
                    first_node_id, 
                    first_node_ip
                )
                node_info.append({"name": node_name, "node_id": first_node_id, "ip": first_node_ip})
            else:
                node_id, node_ip = start_node(
                    plan, 
                    node_name, 
                    participant, 
                    binary,
                    chain_id,
                    babylond_args, 
                    config_folder, 
                    genesis_file, 
                    mnemonic,
                    False, 
                    first_node_id, 
                    first_node_ip
                )
                node_info.append({"name": node_name, "node_id": node_id, "ip": node_ip})
            
            node_counter += 1
    
    return node_info

def start_node(plan, node_name, participant, binary, chain_id, babylond_args, config_folder, genesis_file, mnemonic, is_first_node, first_node_id, first_node_ip):
    image = participant["image"]
    min_cpu = participant.get("min_cpu", 1000)
    min_memory = participant.get("min_memory", 1024)
    
    seed_options = ""
    if not is_first_node:
        seed_address = "{}@{}:{}".format(first_node_id, first_node_ip, 26656)
        seed_options = "--p2p.seeds {}".format(seed_address)
    
    template_data = {
        "NodeName": node_name,
        "ChainID": chain_id,
        "Binary": binary,
        "ConfigFolder": config_folder,
        "BabylondArgs": babylond_args,
        "SeedOptions": seed_options,
        "Mnemonic": mnemonic,
    }
    
    start_script_template = plan.render_templates(
        config={
            "start-node.sh": struct(
                template=read_file("templates/start-node.sh.tmpl"),
                data=template_data
            )
        },
        name="{}-start-script".format(node_name)
    )
    
    files = {
        "/tmp/genesis": genesis_file,
        "/tmp/scripts": start_script_template
    }
    
    ports = {
        "rpc": PortSpec(number=26657, transport_protocol="TCP", wait="2m"),
        "p2p": PortSpec(number=26656, transport_protocol="TCP", wait=None),
        "grpc": PortSpec(number=9090, transport_protocol="TCP", wait="2m"),
        "api": PortSpec(number=1317, transport_protocol="TCP", wait="2m"),
        "prometheus": PortSpec(number=26660, transport_protocol="TCP", wait=None)
    }
    
    min_cpu_millicores = min_cpu
    min_memory_mb = min_memory
    
    service = plan.add_service(
        name=node_name,
        config=ServiceConfig(
            image=image,
            ports=ports,
            files=files,
            entrypoint=["/bin/sh", "/tmp/scripts/start-node.sh"],
            min_cpu=min_cpu_millicores,
            min_memory=min_memory_mb
        )
    )
    
    # Get node ID from the running service
    node_id_result = plan.exec(
        service_name=node_name, 
        recipe=ExecRecipe(
            command=[binary, "tendermint", "show-node-id"]
        )
    )
    node_id = node_id_result["output"].replace("\n", "")
    node_ip = service.ip_address
    
    return node_id, node_ip
