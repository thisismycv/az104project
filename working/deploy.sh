#!/bin/bash
set -e

RG="virtualmachines-rg"
LOCATION="eastus"
ADMIN_USERNAME="azureuser"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?Error: ADMIN_PASSWORD environment variable is not set}"
WORKSPACE="lgvms1"
VMS=("vm-web" "vm-db" "vm-w11")

az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name monitor-control-service --yes || true


echo "Step 1 - RG"
az group create -n "$RG" -l "$LOCATION"


echo "Step 2 - Network"
az deployment group create \
  -g "$RG" \
  --template-file templatenetworking.json \
  --parameters location="$LOCATION"


echo "Step 3 - VMs"
az deployment group create \
  -g "$RG" \
  --template-file deployvm.json \
  --parameters \
    adminUsername="$ADMIN_USERNAME" \
    adminPassword="$ADMIN_PASSWORD" \
    location="$LOCATION"


echo "Waiting for VM provisioning..."
for VM in "${VMS[@]}"; do
  echo "Waiting for $VM to be created..."
  az vm wait \
    --created \
    -g "$RG" \
    -n "$VM"
done


echo "Step 4 - Public IP"
for VM in "${VMS[@]}"; do

  NIC_ID=$(az vm show -g "$RG" -n "$VM" --query "networkProfile.networkInterfaces[0].id" -o tsv)
  NIC_NAME=$(basename "$NIC_ID")
  IP_NAME="public-ip-$VM"

  az network public-ip create \
    -g "$RG" \
    -n "$IP_NAME" \
    -l "$LOCATION" \
    --sku Standard \
    --allocation-method Static

  az network nic ip-config update \
    -g "$RG" \
    --nic-name "$NIC_NAME" \
    -n ipconfig1 \
    --public-ip-address "$IP_NAME"

done


echo "Step 5 - Workspace"
az monitor log-analytics workspace create \
  -g "$RG" \
  -n "$WORKSPACE" \
  -l "$LOCATION"

WS_ID=$(az monitor log-analytics workspace show \
  -g "$RG" \
  -n "$WORKSPACE" \
  --query id -o tsv)


echo "Step 6 - DCR"
az monitor data-collection rule create \
  -g "$RG" \
  -n dcr-vms \
  -l "$LOCATION" \
  --destinations '{
    "logAnalytics":[
      {
        "name":"logAnalytics",
        "workspaceResourceId":"'"$WS_ID"'"
      }
    ]
  }' \
  --data-flows '[
    {
      "streams":["Microsoft-Perf"],
      "destinations":["logAnalytics"]
    }
  ]'


echo "Step 7 - Install agent"
for VM in "${VMS[@]}"; do

  echo "Processing $VM"

  OS=$(az vm show \
    -g "$RG" \
    -n "$VM" \
    --query "storageProfile.osDisk.osType" \
    -o tsv)

  echo "OS = $OS"

  if [ "$OS" = "Linux" ]; then
    az vm extension set \
      -g "$RG" \
      --vm-name "$VM" \
      --publisher Microsoft.Azure.Monitor \
      --name AzureMonitorLinuxAgent \
      --version 1.0
  else
    az vm extension set \
      -g "$RG" \
      --vm-name "$VM" \
      --publisher Microsoft.Azure.Monitor \
      --name AzureMonitorWindowsAgent \
      --version 1.0
  fi

  echo "Verifying extension provisioning state for $VM..."
  PROVISION_STATE=$(az vm extension show \
    -g "$RG" \
    --vm-name "$VM" \
    --name "$([ "$OS" = "Linux" ] && echo AzureMonitorLinuxAgent || echo AzureMonitorWindowsAgent)" \
    --query "provisioningState" -o tsv)

  if [ "$PROVISION_STATE" != "Succeeded" ]; then
    echo "ERROR: Extension on $VM did not provision successfully. State: $PROVISION_STATE"
    exit 1
  fi

  echo "Extension on $VM provisioned successfully."

  VM_ID=$(az vm show -g "$RG" -n "$VM" --query id -o tsv)

  az monitor data-collection rule association create \
    -g "$RG" \
    --name "assoc-$VM" \
    --rule dcr-vms \
    --resource "$VM_ID"

done


echo "DONE"