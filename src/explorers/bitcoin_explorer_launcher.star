def launch_bitcoin_explorer(plan, btc_info):
    bitcoin_explorer = plan.add_service(
        name="bitcoin-explorer",
        config=ServiceConfig(
            image="blockstream/esplora:latest",
            ports={"http": PortSpec(number=5000, transport_protocol="TCP", wait="2m")},
            env_vars={
                "DAEMON_RPC_ADDR": btc_info["rpc_url"].replace("http://", ""),
                "DAEMON_P2P_ADDR": "bitcoin-signet:38333",
                "NETWORK": "signet"
            },
            min_cpu=500,
            min_memory=512
        )
    )
    
    return bitcoin_explorer

def deploy(plan, btc_info):
    return launch_bitcoin_explorer(plan, btc_info)
