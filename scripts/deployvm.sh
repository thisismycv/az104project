#!/bin/bash

TEMPLATE_FILE="$1"
PARAMS_FILE="$2"
RG="virtualmachines-rg"
DEPLOYMENT_NAME="vmdeploy-$(date +%s)"

az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RG" \
  --template-file "$TEMPLATE_FILE" \
  --parameters @"$PARAMS_FILE" \
  --no-wait

echo "Deployment started: $DEPLOYMENT_NAME"

