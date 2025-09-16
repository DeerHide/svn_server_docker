#!/usr/bin/env bash

set -eo pipefail

# Create data directory if it doesn't exist
mkdir -p ./data

# Set correct permissions for the data directory
sudo chown -R 1000:1000 ./data
sudo chmod -R 755 ./data

# Launch the container
docker-compose up -d