#!/bin/bash

# Init repository
docker exec kopia-server kopia repository create filesystem --path=/repository

# Add user
docker exec kopia-server kopia server user add \
    --user=${KOPIA_SERVER_USERNAME:-admin} \
    --password=${KOPIA_SERVER_PASSWORD:-admin}

# Check status
docker exec kopia-server kopia repository status 