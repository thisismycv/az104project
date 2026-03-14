#!/bin/bash

# Usage: ./deploy_loganalytics.sh <resource-group> <workspace-name> <location>

RG=$1
WORKSPACE_NAME=$2
LOCATION=${3:-eastus}

if [ -z "$RG" ] || [ -z "$WORKSPACE_NAME" ]; then
  echo "Usage: $0 <resource-group> <workspace-name> [location]"
  exit 1
fi

echo "Deploying Log Analytics workspace '$WORKSPACE_NAME' in RG '$RG' at location '$LOCATION'..."

az deployment group create \
  --resource-group "$RG" \
  --template-file loganalytics.json \
  --parameters workspaceName="$WORKSPACE_NAME" location="$LOCATION"

echo "Deployment finished."
