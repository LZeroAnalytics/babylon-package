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
                "MONGO_INITDB_ROOT_PASSWORD": "${MONGO_PASSWORD:-dev}"
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
    
    indexer_service = plan.add_service(
        name="babylon-staking-indexer",
        config=ServiceConfig(
            image="babylon-staking-indexer:latest",
            ports={"metrics": PortSpec(number=8081, transport_protocol="TCP")},
            env_vars={
                "MONGODB_URI": backend_args["mongo_uri"],
                "BTC_RPC_URL": backend_args["btc_rpc"],
                "BABYLON_RPC_URL": "http://{}:26657".format(list(backend_args["babylon_networks"].values())[0][0]["ip"])
            },
            min_cpu=500,
            min_memory=512
        )
    )
    
    api_service = plan.add_service(
        name="babylon-staking-api",
        config=ServiceConfig(
            image="babylon-staking-api:latest",
            ports={"http": PortSpec(number=8080, transport_protocol="TCP", wait="2m")},
            env_vars={
                "MONGODB_URI": backend_args["mongo_uri"],
                "RABBITMQ_URL": "amqp://user:${RABBITMQ_PASSWORD:-dev}@rabbitmq:5672/",
                "BTC_RPC_URL": backend_args["btc_rpc"]
            },
            min_cpu=1000,
            min_memory=1024
        )
    )
    
    expiry_service = plan.add_service(
        name="babylon-expiry-checker",
        config=ServiceConfig(
            image="babylon-staking-api:latest",
            env_vars={
                "MONGODB_URI": backend_args["mongo_uri"],
                "CHECK_INTERVAL": "60"
            },
            entrypoint=["/bin/staking-api-service", "expiry-checker"],
            min_cpu=200,
            min_memory=256
        )
    )
    
    global_config_service = plan.add_service(
        name="babylon-global-config",
        config=ServiceConfig(
            image="babylon-staking-api:latest",
            ports={"http": PortSpec(number=8082, transport_protocol="TCP")},
            env_vars={
                "MONGODB_URI": backend_args["mongo_uri"]
            },
            entrypoint=["/bin/staking-api-service", "global-config"],
            min_cpu=200,
            min_memory=256
        )
    )
    
    plan.print("Staking backend services deployed successfully")
    
    return {
        "mongodb": mongodb_service,
        "babylon-staking-indexer": indexer_service,
        "babylon-staking-api": api_service,
        "babylon-expiry-checker": expiry_service,
        "babylon-global-config": global_config_service
    }
