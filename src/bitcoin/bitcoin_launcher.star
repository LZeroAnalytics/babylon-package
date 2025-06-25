def deploy(plan, parsed_args):
    bitcoin_config = parsed_args["bitcoin"]
    
    plan.print("Deploying Bitcoin Signet...")
    
    bitcoin_service = plan.add_service(
        name="bitcoin-signet",
        config=ServiceConfig(
            image=bitcoin_config["image"],
            ports={
                "rpc": PortSpec(number=38332, transport_protocol="TCP", wait="30s"),
                "p2p": PortSpec(number=38333, transport_protocol="TCP", wait=None)
            },
            env_vars={
                "BITCOIN_NETWORK": "signet",
                "RPC_USER": "bitcoin",
                "RPC_PASSWORD": "${BITCOIN_RPC_PASSWORD:-dev}",
                "RPC_ALLOW_IP": "0.0.0.0/0"
            },
            cmd=[
                "bitcoind",
                "-signet",
                "-server",
                "-rpcbind=0.0.0.0:38332",
                "-rpcallowip=0.0.0.0/0",
                "-rpcuser=bitcoin",
                "-rpcpassword=${BITCOIN_RPC_PASSWORD:-dev}",
                "-fallbackfee=0.0002",
                "-txindex=1"
            ]
        )
    )
    
    if bitcoin_config.get("auto_mine", True):
        mine_interval = bitcoin_config.get("mine_interval", 10)
        
        miner_script = plan.render_templates(
            config={
                "mine_blocks.sh": struct(
                    template="""#!/bin/bash
set -e

echo "Starting Bitcoin Signet auto-miner..."
echo "Mining interval: {{ .MineInterval }} seconds"

# Wait for bitcoind to be ready
sleep 15

# Create descriptor wallet (modern Bitcoin Core format)
echo "Creating descriptor wallet..."
bitcoin-cli -signet -rpcuser=bitcoin -rpcpassword=${BITCOIN_RPC_PASSWORD:-dev} -rpcconnect=bitcoin-signet -rpcport=38332 createwallet "miner" false false "" false true true || echo "Wallet creation attempted"

# Load wallet to ensure it's available
echo "Loading wallet..."
bitcoin-cli -signet -rpcuser=bitcoin -rpcpassword=${BITCOIN_RPC_PASSWORD:-dev} -rpcconnect=bitcoin-signet -rpcport=38332 loadwallet "miner" || echo "Wallet load attempted"

# Generate initial address for mining
MINING_ADDRESS=$(bitcoin-cli -signet -rpcuser=bitcoin -rpcpassword=${BITCOIN_RPC_PASSWORD:-dev} -rpcconnect=bitcoin-signet -rpcport=38332 getnewaddress)
echo "Mining to address: $MINING_ADDRESS"

while true; do
    echo "Mining block..."
    bitcoin-cli -signet -rpcuser=bitcoin -rpcpassword=${BITCOIN_RPC_PASSWORD:-dev} -rpcconnect=bitcoin-signet -rpcport=38332 generatetoaddress 1 $MINING_ADDRESS
    echo "Block mined, waiting {{ .MineInterval }} seconds..."
    sleep {{ .MineInterval }}
done
""",
                    data={"MineInterval": mine_interval}
                )
            },
            name="bitcoin-miner-script"
        )
        
        plan.add_service(
            name="bitcoin-miner",
            config=ServiceConfig(
                image="bitcoin/bitcoin:latest",
                files={
                    "/tmp/scripts": miner_script
                },
                entrypoint=["/bin/bash", "/tmp/scripts/mine_blocks.sh"],
                env_vars={
                    "BITCOIN_NETWORK": "signet"
                }
            )
        )
    
    rpc_password = "${BITCOIN_RPC_PASSWORD:-dev}"
    rpc_url = "http://bitcoin:{}@{}:{}".format(rpc_password, bitcoin_service.ip_address, 38332)
    
    plan.print("Bitcoin Signet deployed successfully")
    plan.print("RPC URL: {}".format(rpc_url))
    
    return {
        "bitcoin-signet": bitcoin_service,
        "rpc_url": rpc_url,
        "rpc_host": bitcoin_service.ip_address,
        "rpc_port": 38332,
        "rpc_user": "bitcoin",
        "rpc_password": "${BITCOIN_RPC_PASSWORD:-dev}"
    }
