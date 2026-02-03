#/bin/bash
if [ -z "$1" ]; then
  echo "Usage: $0 <user-upn-or-id>"
  exit 1
fi
USER_INPUT="$1"
az group create \
  --name virtualmachines-rg \
  --location eastus

