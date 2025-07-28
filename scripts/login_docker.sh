#!/usr/bin/env bash

# Errors handling
set -eo pipefail

# Load environment variables from .env file
if [[ -f .env ]]; then
  set -a && source .env && set +a
fi

# Login to the container registry
docker login ghcr.io -u $GHCR_USERNAME -p $GHCR_PASSWORD