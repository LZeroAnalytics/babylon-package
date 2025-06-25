# Babylon Package

A Kurtosis package for deploying private Babylon testnets with Bitcoin Signet integration and full staking backend services.

## Overview

This package provides:
- **Babylon Genesis Chain**: Private Babylon blockchain with configurable validators
- **Bitcoin Signet**: Private Bitcoin Signet network with auto-mining
- **Staking Backend**: Complete BTC-to-Babylon staking infrastructure
- **Faucet Services**: Token distribution for both BTC and BBN
- **Monitoring**: Health checks and metrics endpoints

## Quick Start

### Prerequisites

- [Kurtosis CLI](https://docs.kurtosis.com/install) >= 0.85
- [Docker](https://docs.docker.com/get-docker/) >= 25.x

### Deploy Private Testnet

```bash
# Clean any existing enclaves
kurtosis clean -a

# Deploy with default configuration
kurtosis run --enclave test .

# Deploy with custom validators
kurtosis run --enclave test . --args-file examples/multi-validator.yaml
```

### Connect to Existing Chains

```bash
# Connect to public Babylon testnet and Bitcoin Signet
kurtosis run --enclave test . --args-file examples/public-chains.yaml
```

## Configuration

### Basic Configuration

Create a YAML file with your desired configuration:

```yaml
chains:
  - name: "babylon"
    chain_id: "babylon-local"
    participants:
      - count: 3
        account_balance: "1000000000000000"
        bond_amount: "300000000000000"
    additional_services:
      - "faucet"

bitcoin:
  auto_mine: true
  mine_interval: 10

staking_backend:
  enabled: true
```

### Advanced Configuration

```yaml
chains:
  - name: "babylon"
    chain_id: "babylon-devnet-1"
    participants:
      - count: 4
        image: "cosmoshub/gaia:v7.1.0"
        min_cpu: 2000
        min_memory: 2048
    denom:
      name: "ubbn"
      display: "bbn"
      symbol: "BBN"
    modules:
      epoching:
        epoch_interval: 400
      btccheckpoint:
        btc_confirmation_depth: 6

bitcoin:
  auto_mine: true
  mine_interval: 5
  image: "ruimarinho/bitcoin-core:latest"

staking_backend:
  enabled: true
  indexer:
    min_cpu: 4000
    min_memory: 8192
```

## API Endpoints

### Faucet Service (Port 5000)

```bash
# Fund Babylon address
curl -X POST http://localhost:5000/fund_bbn \
  -H "Content-Type: application/json" \
  -d '{"address":"bbn1...", "amount":"1000000000"}'

# Fund Bitcoin address  
curl -X POST http://localhost:5000/fund_btc \
  -H "Content-Type: application/json" \
  -d '{"address":"tb1q...", "amount":"1.0"}'

# Get network stats
curl http://localhost:5000/stats
```

### Staking API (Port 8080)

```bash
# Get staking statistics
curl http://localhost:8080/v2/stats

# Delegate BTC (example)
curl -X POST http://localhost:8080/v2/delegate \
  -H "Content-Type: application/json" \
  -d '{
    "staker_btc_pk": "...",
| Babylon Explorer | 3000 | HTTP | TypeScript block explorer |
| Bitcoin Explorer | 5000 | HTTP | Esplora-based explorer |
| MongoDB | 27017 | TCP | Database for staking backend |
| RabbitMQ | 5672 | TCP | Message queue for staking events |

### Testing Real Blockchain Functionality

After deployment, verify the services are working:

```bash
# Check Babylon node status
curl http://localhost:26657/status

# Check Bitcoin Signet status  
curl -u bitcoin:password http://localhost:38332 -d '{"jsonrpc":"1.0","id":"test","method":"getblockcount","params":[]}'

# Check staking API
curl http://localhost:8080/v1/stats

# Access block explorers
open http://localhost:3000  # Babylon Explorer
open http://localhost:5000  # Bitcoin Explorer
```

    "finality_provider_btc_pk": "...",
    "staking_amount": 100000,
    "staking_time": 1000
  }'
```

## Health Checks

```bash
# Check Babylon chain status
babylond status | jq .SyncInfo.catching_up

# Check Bitcoin Signet blocks
bitcoin-cli -signet getblockcount

# Check staking API health
curl localhost:8080/v2/stats
```

## Architecture

### Components

1. **Bitcoin Signet**: Private Bitcoin network for testing BTC transactions
2. **Babylon Chain**: Cosmos-based blockchain with BTC staking modules
3. **Staking Indexer**: Monitors Bitcoin transactions and updates staking state
4. **Staking API**: REST/GraphQL interface for staking operations
5. **Staking Expiry Checker**: Automated unbonding of expired stakes
6. **Global Config**: Network parameter management
7. **MongoDB**: Persistence layer for staking data

### Network Topology

- **Seed Node**: First Babylon validator acts as seed for network formation
- **Validators**: Additional validators connect to seed node
- **Bitcoin Integration**: Signet provides realistic Bitcoin transaction environment
- **Service Mesh**: All services communicate via Docker networking

## Examples

### Multi-Validator Setup

```yaml
# examples/multi-validator.yaml
chains:
  - name: "babylon"
    participants:
      - count: 4
        bond_amount: "500000000000000"
    additional_services: ["faucet"]
```

### Production-like Configuration

```yaml
# examples/production.yaml
chains:
  - name: "babylon"
    participants:
      - count: 7
        min_cpu: 2000
        min_memory: 4096
    modules:
      staking:
        max_validators: 100
      epoching:
        epoch_interval: 600

bitcoin:
  mine_interval: 30

staking_backend:
  indexer:
    min_cpu: 4000
    min_memory: 8192
```

## Development

### Building Custom Images

If you need to build custom Babylon or staking backend images:

```bash
# Build Babylon node
git clone https://github.com/babylonchain/babylon.git
cd babylon && make install
docker build -t babylonchain/babylond:custom .

# Update configuration to use custom image
# In your YAML config:
participants:
  - image: "babylonchain/babylond:custom"
```

### Testing

```bash
# Run full test suite
kurtosis clean -a
kurtosis run --enclave test .

# Verify all services are healthy
curl localhost:5000/health
curl localhost:8080/v2/stats

# Test staking flow
curl -X POST localhost:5000/fund_btc -d '{"address":"tb1q...", "amount":"1"}'
# ... perform staking operations
```

## Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker resources and image availability
2. **Network connectivity**: Ensure proper seed node configuration
3. **Staking API errors**: Verify Bitcoin and Babylon RPC connectivity
4. **Block production stopped**: Check validator configuration and networking

### Debug Commands

```bash
# Check service logs
kurtosis service logs test babylon-node-1

# Inspect service details
kurtosis service inspect test staking-api

# Check enclave status
kurtosis enclave inspect test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `kurtosis run --enclave test .`
5. Submit a pull request

## License

This project is licensed under the MIT License.
