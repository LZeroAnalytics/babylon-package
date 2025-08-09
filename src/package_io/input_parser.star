def read_json_file(file_path):
    local_contents = read_file(src=file_path)
    return json.decode(local_contents)

DEFAULT_BABYLON_FILE = "./babylon_defaults.json"

def apply_chain_defaults(chain, defaults):
    chain["name"] = chain.get("name", defaults["name"])
    chain["type"] = chain.get("type", defaults["type"])
    chain["chain_id"] = chain.get("chain_id", defaults["chain_id"])
    chain["binary"] = chain.get("binary", defaults["binary"])
    chain["app_version"] = chain.get("app_version", defaults["app_version"])
    chain["genesis_delay"] = chain.get("genesis_delay", defaults["genesis_delay"])
    chain["initial_height"] = chain.get("initial_height", defaults["initial_height"])

    chain["denom"] = chain.get("denom", {})
    for key, value in defaults["denom"].items():
        chain["denom"][key] = chain["denom"].get(key, value)

    chain["faucet"] = chain.get("faucet", {})
    for key, value in defaults["faucet"].items():
        chain["faucet"][key] = chain["faucet"].get(key, value)

    chain["consensus"] = chain.get("consensus", {})
    for key, value in defaults["consensus"].items():
        chain["consensus"][key] = chain["consensus"].get(key, value)

    chain["modules"] = chain.get("modules", {})
    for module, module_defaults in defaults["modules"].items():
        chain["modules"][module] = chain["modules"].get(module, {})
        for key, value in module_defaults.items():
            chain["modules"][module][key] = chain["modules"][module].get(key, value)

    if "participants" not in chain:
        chain["participants"] = defaults["participants"]
    else:
        default_participant = defaults["participants"][0]
        participants = []
        for participant in chain["participants"]:
            for key, value in default_participant.items():
                participant[key] = participant.get(key, value)
            participants.append(participant)
        chain["participants"] = participants

    if "additional_services" not in chain:
        chain["additional_services"] = defaults["additional_services"]

    chain["bitcoin"] = chain.get("bitcoin", defaults["bitcoin"])
    chain["staking_backend"] = chain.get("staking_backend", defaults["staking_backend"])

    return chain

def validate_input_args(input_args):
    if not input_args or "chains" not in input_args:
        fail("Input arguments must include the 'chains' field.")

    chain_names = []
    for chain in input_args["chains"]:
        if "name" not in chain or "type" not in chain:
            fail("Each chain must specify a 'name' and a 'type'.")
        if chain["name"] in chain_names:
            fail("Duplicate chain name found: " + chain["name"])
        if chain["type"] != "babylon":
            fail("Unsupported chain type: "+ chain["type"])
        chain_names.append(chain["name"])

def input_parser(input_args=None):
    babylon_defaults = read_json_file(DEFAULT_BABYLON_FILE)

    result = {"chains": []}

    if not input_args:
        input_args = {"chains": [babylon_defaults]}

    validate_input_args(input_args)

    if "chains" not in input_args:
        result["chains"].append(babylon_defaults)
    else:
        for chain in input_args["chains"]:
            chain_type = chain.get("type", "babylon")
            if chain_type == "babylon":
                defaults = babylon_defaults
            else:
                fail("Unsupported chain type: " + chain_type)

            chain_config = apply_chain_defaults(chain, defaults)
            result["chains"].append(chain_config)

    result["bitcoin"] = input_args.get("bitcoin", babylon_defaults["bitcoin"])
    result["staking_backend"] = input_args.get("staking_backend", babylon_defaults["staking_backend"])

    return result
