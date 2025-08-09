def launch_babylon_explorer(plan, babylon_networks):
    babylon_explorer = plan.add_service(
        name="babylon-explorer",
        config=ServiceConfig(
            image="babylon-explorer:latest",
            ports={"http": PortSpec(number=3000, transport_protocol="TCP", wait="2m")},
            env_vars={
                "VITE_BABYLON_RPC": "http://{}:26657".format(babylon_networks[list(babylon_networks.keys())[0]][0]["ip"]),
                "VITE_BABYLON_API": "http://{}:1317".format(babylon_networks[list(babylon_networks.keys())[0]][0]["ip"]),
                "VITE_STAKING_API": "http://localhost:8080"
            },
            min_cpu=500,
            min_memory=512
        )
    )
    
    return babylon_explorer

def deploy(plan, babylon_networks):
    return launch_babylon_explorer(plan, babylon_networks)
