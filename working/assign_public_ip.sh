#!/bin/bash
# assign_public_ip.sh
# Usage: ./assign_public_ip.sh <resource-group> <vm-name> <public-ip-name> <location>

set -e

# --- Parameters ---
RESOURCE_GROUP=$1
VM_NAME=$2
PUBLIC_IP_NAME=$3
LOCATION=$4

if [ -z "$RESOURCE_GROUP" ] || [ -z "$VM_NAME" ] || [ -z "$PUBLIC_IP_NAME" ] || [ -z "$LOCATION" ]; then
    echo "Usage: $0 <resource-group> <vm-name> <public-ip-name> <location>"
    exit 1
fi

echo "Getting NIC of VM '$VM_NAME' in RG '$RESOURCE_GROUP'..."
NIC_ID=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" \
    -o tsv)

if [ -z "$NIC_ID" ]; then
    echo "Failed to find NIC for VM $VM_NAME"
    exit 1
fi

# Extract NIC name from the full resource ID
NIC_NAME=$(basename "$NIC_ID")

echo "Creating Public IP '$PUBLIC_IP_NAME'..."
az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static

echo "Associating Public IP with NIC..."
az network nic ip-config update \
    --resource-group "$RESOURCE_GROUP" \
    --nic-name "$NIC_NAME" \
    --name ipconfig1 \
    --public-ip-address "$PUBLIC_IP_NAME"

echo "Done! Public IP '$PUBLIC_IP_NAME' assigned to VM '$VM_NAME'."
az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query "{IP: ipAddress}" \
    -o table