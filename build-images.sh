#!/bin/bash
set -e

echo "Building all Docker images for Babylon package..."

echo "Building staking backend images..."
cd /home/ubuntu/repos/staking-api-service
docker build -f contrib/images/staking-api-service/Dockerfile -t babylon-staking-api:latest .

cd /home/ubuntu/repos/babylon-staking-indexer
docker build -f contrib/images/babylon-staking-indexer/Dockerfile -t babylon-staking-indexer:latest .

echo "Building Babylon explorer..."
cd /home/ubuntu/repos/babylon-package/src/explorers/babylon-explorer
npm install
npm run build
docker build -t babylon-explorer:latest .

echo "All Docker images built successfully!"
echo "Available images:"
echo "- babylon-staking-api:latest"
echo "- babylon-staking-indexer:latest"
echo "- babylon-explorer:latest"
echo "- blockstream/esplora:latest (will be pulled automatically)"
