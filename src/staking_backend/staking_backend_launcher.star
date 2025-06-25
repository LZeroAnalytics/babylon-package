def deploy(plan, backend_args, parsed_args):
    staking_config = parsed_args["staking_backend"]
    
    if not staking_config.get("enabled", True):
        plan.print("Staking backend disabled, skipping deployment")
        return {}
    
    plan.print("Deploying staking backend services...")
    
    mongodb_service = plan.add_service(
        name="mongodb",
        config=ServiceConfig(
            image="mongo:6.0",
            ports={
                "mongodb": PortSpec(number=27017, transport_protocol="TCP", wait="30s")
            },
            env_vars={
                "MONGO_INITDB_ROOT_USERNAME": "admin",
                "MONGO_INITDB_ROOT_PASSWORD": "password123"
            }
        )
    )
    
    plan.wait(
        service_name="mongodb",
        recipe=GetHttpRequestRecipe(
            port_id="mongodb",
            endpoint="/",
            extract={}
        ),
        field="code",
        assertion="==",
        target_value=200,
        interval="5s",
        timeout="60s",
        description="Waiting for MongoDB to be ready"
    )
    
    indexer_config = staking_config["indexer"]
    indexer_service = plan.add_service(
        name="staking-indexer",
        config=ServiceConfig(
            image=indexer_config["image"],
            env_vars={
                "BTC_RPC_URL": backend_args["btc_rpc"],
                "BABYLON_RPC_URL": list(backend_args["babylon_networks"].values())[0][0]["name"] + ":26657",
                "MONGO_URI": backend_args["mongo_uri"],
                "MONGO_USERNAME": "admin",
                "MONGO_PASSWORD": "password123"
            },
            min_cpu=indexer_config.get("min_cpu", 2000),
            min_memory=indexer_config.get("min_memory", 4096)
        )
    )
    
    api_config = staking_config["api"]
    api_service = plan.add_service(
        name="staking-api",
        config=ServiceConfig(
            image=api_config["image"],
            ports={
                "api": PortSpec(number=8080, transport_protocol="TCP", wait="30s"),
                "metrics": PortSpec(number=9090, transport_protocol="TCP", wait=None)
            },
            env_vars={
                "BTC_RPC_URL": backend_args["btc_rpc"],
                "BABYLON_RPC_URL": list(backend_args["babylon_networks"].values())[0][0]["name"] + ":26657",
                "MONGO_URI": backend_args["mongo_uri"],
                "MONGO_USERNAME": "admin",
                "MONGO_PASSWORD": "password123",
                "PORT": "8080"
            },
            min_cpu=api_config.get("min_cpu", 1000),
            min_memory=api_config.get("min_memory", 2048)
        )
    )
    
    expiry_config = staking_config["expiry_checker"]
    expiry_service = plan.add_service(
        name="staking-expiry-checker",
        config=ServiceConfig(
            image=expiry_config["image"],
            env_vars={
                "BTC_RPC_URL": backend_args["btc_rpc"],
                "BABYLON_RPC_URL": list(backend_args["babylon_networks"].values())[0][0]["name"] + ":26657",
                "MONGO_URI": backend_args["mongo_uri"],
                "MONGO_USERNAME": "admin",
                "MONGO_PASSWORD": "password123",
                "CHECK_INTERVAL": "60"
            },
            min_cpu=expiry_config.get("min_cpu", 500),
            min_memory=expiry_config.get("min_memory", 1024)
        )
    )
    
    global_config_config = staking_config["global_config"]
    global_config_service = plan.add_service(
        name="global-config",
        config=ServiceConfig(
            image=global_config_config["image"],
            ports={
                "api": PortSpec(number=8081, transport_protocol="TCP", wait="30s")
            },
            env_vars={
                "BABYLON_RPC_URL": list(backend_args["babylon_networks"].values())[0][0]["name"] + ":26657",
                "PORT": "8081"
            },
            min_cpu=global_config_config.get("min_cpu", 500),
            min_memory=global_config_config.get("min_memory", 512)
        )
    )
    
    plan.print("Staking backend services deployed successfully")
    
    return {
        "mongodb": mongodb_service,
        "staking-indexer": indexer_service,
        "staking-api": api_service,
        "staking-expiry-checker": expiry_service,
        "global-config": global_config_service
    }
