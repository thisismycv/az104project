# ============================================================
# Full standalone Azure deployment script (PowerShell)
# Resource Group, Networking, VMs, Public IPs, Log Analytics, Agent
# ============================================================

$ErrorActionPreference = "Stop"

# -------------------------
# Variables
# -------------------------
$RG             = "virtualmachines-rg"
$LOCATION       = "eastus"
$ADMIN_USERNAME = "azureuser"
$ADMIN_PASSWORD = "WiD0GQSv1X1V5Ibv"
$VNET_NAME      = "example-vnet"
$WORKSPACE      = "lgvms1"
$VMS            = @("vm-web", "vm-db", "vm-w11")

# -------------------------
# Ensure Azure CLI extensions are installed
# -------------------------
az config set extension.use_dynamic_install=yes_without_prompt
az config set extension.dynamic_install_allow_preview=true
az extension add --name monitor-control-service --yes
az extension add --name monitor --yes

# ============================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Step 1: Create Resource Group: $RG"
Write-Host "==========================================================" -ForegroundColor Cyan
az group create --name $RG --location $LOCATION
Write-Host "Resource Group created successfully." -ForegroundColor Green
Start-Sleep -Seconds 5

# ============================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Step 2: Deploy Networking"
Write-Host "==========================================================" -ForegroundColor Cyan
az deployment group create `
    --resource-group $RG `
    --template-file templatenetworking.json `
    --parameters location=$LOCATION
Write-Host "Networking deployed successfully." -ForegroundColor Green
Start-Sleep -Seconds 5

# ============================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Step 3: Deploy VMs"
Write-Host "==========================================================" -ForegroundColor Cyan
az deployment group create `
    --resource-group $RG `
    --template-file deployvm.json `
    --parameters `
        adminUsername=$ADMIN_USERNAME `
        adminPassword=$ADMIN_PASSWORD `
        location=$LOCATION
Write-Host "VMs deployed successfully." -ForegroundColor Green
Start-Sleep -Seconds 10

# ============================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Step 4: Assign Public IPs"
Write-Host "==========================================================" -ForegroundColor Cyan
foreach ($VM in $VMS) {
    $IP_NAME = "public-ip-$VM"
    Write-Host "--- Processing $VM ---"

    $NIC_ID = az vm show `
        --resource-group $RG `
        --name $VM `
        --query "networkProfile.networkInterfaces[0].id" `
        -o tsv 2>$null

    if (-not $NIC_ID) {
        Write-Host "WARNING: Could not find NIC for $VM, skipping..." -ForegroundColor Yellow
        continue
    }

    $NIC_NAME = Split-Path $NIC_ID -Leaf

    az network public-ip create `
        --resource-group $RG `
        --name $IP_NAME `
        --location $LOCATION `
        --sku Standard `
        --allocation-method Static `
        --output none

    az network public-ip wait `
        --resource-group $RG `
        --name $IP_NAME `
        --created

    az network nic ip-config update `
        --resource-group $RG `
        --nic-name $NIC_NAME `
        --name ipconfig1 `
        --public-ip-address $IP_NAME `
        --output none

    $ASSIGNED_IP = az network public-ip show `
        --resource-group $RG `
        --name $IP_NAME `
        --query ipAddress -o tsv

    Write-Host "$VM --> $ASSIGNED_IP" -ForegroundColor Green
}
Start-Sleep -Seconds 5

# ============================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Step 5: Deploy Log Analytics Workspace"
Write-Host "==========================================================" -ForegroundColor Cyan
az monitor log-analytics workspace create `
    --resource-group $RG `
    --workspace-name $WORKSPACE `
    --location $LOCATION `
    --output none
Start-Sleep -Seconds 5

# ============================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Step 6: Install Azure Monitor Agent & Data Collection Rule"
Write-Host "==========================================================" -ForegroundColor Cyan

$WS_ID = az monitor log-analytics workspace show `
    --resource-group $RG `
    --workspace-name $WORKSPACE `
    --query id -o tsv

Write-Host "Creating Data Collection Rule..."

# Write DCR JSON to a temp file — avoids all shell serialization/OrderedDict issues
$DCR_JSON = @"
{
  "destinations": {
    "logAnalytics": [
      {
        "workspaceResourceId": "$WS_ID",
        "name": "logAnalytics"
      }
    ]
  },
  "dataFlows": [
    {
      "streams": ["Microsoft-Perf"],
      "destinations": ["logAnalytics"]
    }
  ]
}
"@

$DCR_FILE = "$env:TEMP\dcr-properties.json"
$DCR_JSON | Out-File -FilePath $DCR_FILE -Encoding utf8

az monitor data-collection rule create `
    --name dcr-vms `
    --resource-group $RG `
    --location $LOCATION `
    --rule-file $DCR_FILE `
    --output none

Start-Sleep -Seconds 5

# Fetch the full DCR resource ID — required for association
$DCR_ID = az monitor data-collection rule show `
    --name dcr-vms `
    --resource-group $RG `
    --query id -o tsv

foreach ($VM in $VMS) {
    Write-Host "Installing Azure Monitor Agent on $VM..."

    $OS = az vm show `
        --resource-group $RG `
        --name $VM `
        --query "storageProfile.osDisk.osType" `
        -o tsv

    Write-Host "OS = $OS"

    if ($OS -eq "Linux") {
        az vm extension set `
            --resource-group $RG `
            --vm-name $VM `
            --name AzureMonitorLinuxAgent `
            --publisher Microsoft.Azure.Monitor `
            --enable-auto-upgrade true `
            --output none
    } else {
        az vm extension set `
            --resource-group $RG `
            --vm-name $VM `
            --name AzureMonitorWindowsAgent `
            --publisher Microsoft.Azure.Monitor `
            --enable-auto-upgrade true `
            --output none
    }

    $VM_ID = az vm show `
        --resource-group $RG `
        --name $VM `
        --query id -o tsv

    az monitor data-collection rule association create `
        --name "assoc-$VM" `
        --rule $DCR_ID `
        --resource $VM_ID `
        --output none

    Write-Host "Agent installed and DCR associated for $VM." -ForegroundColor Green
}

Start-Sleep -Seconds 5

# ============================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Deployment Complete"
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "`nPublic IPs:"
foreach ($VM in $VMS) {
    $IP = az network public-ip show `
        --resource-group $RG `
        --name "public-ip-$VM" `
        --query ipAddress -o tsv 2>$null
    if (-not $IP) { $IP = "N/A" }
    Write-Host "  $VM : $IP"
}

Write-Host "`nVM list:"
az vm list --resource-group $RG -o table