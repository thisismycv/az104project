#!/bin/bash
set -e

# ============================================================
# Full standalone Azure deployment script
# Resource Group, Networking, VMs, Public IPs, Log Analytics, Agent
# ============================================================

# -------------------------
# Variables
# -------------------------
RG="virtualmachines-rg"
LOCATION="eastus"
ADMIN_USERNAME=$1
ADMIN_PASSWORD=$2
VNET_NAME="example-vnet"
WORKSPACE="lgvms1"
VMS=("vm-web" "vm-db" "vm-w11")

# -------------------------
# Ensure Azure CLI extensions are installed
# -------------------------
az config set extension.use_dynamic_install=yes_without_prompt
az config set extension.dynamic_install_allow_preview=true
az extension add --name -control-service --yes || true
az extension add --name monitor --yes || true

# ============================================================
echo "=========================================================="
echo "Step 1: Create Resource Group: $RG"
echo "=========================================================="
az group create --name "$RG" --location "$LOCATION"
echo "Resource Group created successfully."
sleep 5

# ============================================================
echo "=========================================================="
echo "Step 2: Deploy Networking"
echo "=========================================================="
az deployment group create \
  --resource-group "$RG" \
  --template-file templatenetworking.json \
  --parameters location="$LOCATION"
echo "Networking deployed successfully."
sleep 5

# ============================================================
echo "=========================================================="
echo "Step 3: Deploy VMs"
echo "=========================================================="
az deployment group create \
  --resource-group "$RG" \
  --template-file deployvm.json \
  --parameters \
    adminUsername="$ADMIN_USERNAME" \
    adminPassword="$ADMIN_PASSWORD" \
    location="$LOCATION"
echo "VMs deployed successfully."
sleep 10

# ============================================================
echo "=========================================================="
echo "Step 4: Assign Public IPs"
echo "=========================================================="
for VM in "${VMS[@]}"; do
    IP_NAME="public-ip-${VM}"
    echo "--- Processing $VM ---"

    NIC_ID=$(az vm show \
        --resource-group "$RG" \
        --name "$VM" \
        --query "networkProfile.networkInterfaces[0].id" \
        -o tsv 2>/dev/null)

    if [ -z "$NIC_ID" ]; then
        echo "WARNING: Could not find NIC for $VM, skipping..."
        continue
    fi

    NIC_NAME=$(basename "$NIC_ID")

    az network public-ip create \
        --resource-group "$RG" \
        --name "$IP_NAME" \
        --location "$LOCATION" \
        --sku Standard \
        --allocation-method Static \
        --output none

    az network public-ip wait \
        --resource-group "$RG" \
        --name "$IP_NAME" \
        --created

    az network nic ip-config update \
        --resource-group "$RG" \
        --nic-name "$NIC_NAME" \
        --name ipconfig1 \
        --public-ip-address "$IP_NAME" \
        --output none

    ASSIGNED_IP=$(az network public-ip show \
        --resource-group "$RG" \
        --name "$IP_NAME" \
        --query ipAddress -o tsv)

    echo "$VM --> $ASSIGNED_IP"
done
sleep 5

# ============================================================
echo "=========================================================="
echo "Step 5: Deploy Log Analytics Workspace"
echo "=========================================================="
az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "$WORKSPACE" \
  --location "$LOCATION" \
  --output none
sleep 5

# ============================================================
echo "=========================================================="
echo "Step 6: Install Azure Monitor Agent & Data Collection Rule"
echo "=========================================================="
WS_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RG" \
  --workspace-name "$WORKSPACE" \
  --query id -o tsv)

echo "Creating Data Collection Rule..."
az monitor data-collection rule create \
  --name dcr-vms \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --destinations "[
      {
          \"name\": \"logAnalytics\",
          \"workspaceResourceId\": \"$WS_ID\"
      }
  ]" \
  --data-flows "[
      {
          \"streams\": [\"Microsoft-Perf\"],
          \"destinations\": [\"logAnalytics\"]
      }
  ]" \
  --output none
sleep 5

for VM in "${VMS[@]}"; do
    echo "Installing Azure Monitor agent on $VM..."

    # Linux Agent (safe to run on Windows too, will ignore if OS mismatch)
		    az vm extension set \
			--resource-group "$RG" \
			--vm-name "$VM" \
			--name AzureMonitorLinuxAgent \
			--publisher Microsoft.Azure.Monitor \
			--enable-auto-upgrade true \
			--output none || true			

    # Windows Agent
    az vm extension set \
        --resource-group "$RG" \
        --vm-name "$VM" \
        --name AzureMonitorWindowsAgent \
        --publisher Microsoft.Azure.Monitor \
        --enable-auto-upgrade true \
        --output none || true

    VM_ID=$(az vm show \
        --resource-group "$RG" \
        --name "$VM" \
        --query id -o tsv)

    az monitor data-collection rule association create \
        --name assoc-$VM \
        --rule dcr-vms \
        --resource "$VM_ID" \
        --output none
done
sleep 5

# ============================================================
echo "=========================================================="
echo "Deployment Complete"
echo "=========================================================="

echo "Public IPs:"
for VM in "${VMS[@]}"; do
    IP=$(az network public-ip show \
        --resource-group "$RG" \
        --name public-ip-$VM \
        --query ipAddress -o tsv 2>/dev/null || echo "N/A")
    echo "  $VM : $IP"
done

echo ""
echo "VM list:"
az vm list --resource-group "$RG" -o table
