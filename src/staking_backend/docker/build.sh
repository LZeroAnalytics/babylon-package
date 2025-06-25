#!/bin/bash
set -e

echo "Building staking backend Docker images..."

echo "Building staking-api-service..."
cd /home/ubuntu/repos/staking-api-service
docker build -f contrib/images/staking-api-service/Dockerfile -t babylon-staking-api:latest .

echo "Building babylon-staking-indexer..."
cd /home/ubuntu/repos/babylon-staking-indexer
docker build -f contrib/images/babylon-staking-indexer/Dockerfile -t babylon-staking-indexer:latest .

echo "Docker images built successfully!"
