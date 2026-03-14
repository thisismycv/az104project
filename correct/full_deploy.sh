#!/bin/bash
set -e

# ============================================================
# Full deployment script: Resource Group, Networking, VMs,
# Public IPs, and Log Analytics workspace
# ============================================================

RG="virtualmachines-rg"
LOCATION="eastus"

echo "=========================================================="
echo "Step 1: Create Resource Group: $RG"
echo "=========================================================="
./createrg.sh $RG
echo "Resource Group created successfully."
sleep 5

echo "=========================================================="
echo "Step 2: Deploy Networking Template"
echo "=========================================================="
./templatenetworking.sh templatenetworking.json
echo "Networking deployed successfully."
sleep 5

echo "=========================================================="
echo "Step 3: Deploy VMs Template"
echo "=========================================================="
./deploytemplate.sh template.json
echo "VMs deployed successfully."
sleep 10

echo "=========================================================="
echo "Step 4: Assign Public IPs"
echo "=========================================================="
./assign_public_ip.sh $RG vm-w11 public-ip-w11 $LOCATION
./assign_public_ip.sh $RG vm-web public-ip-web $LOCATION
./assign_public_ip.sh $RG vm-db public-ip-db $LOCATION
echo "Public IPs assigned successfully."
sleep 5

echo "=========================================================="
echo "Step 5: Deploy Log Analytics Workspace"
echo "=========================================================="
./deploy_loganalytics.sh $RG lgvms1 $LOCATION
echo "Log Analytics workspace deployed successfully."
sleep 5

echo "=========================================================="
echo "Deployment finished successfully!"
echo "Check the Azure portal for your resources in RG: $RG"
echo "=========================================================="
