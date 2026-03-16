#!/bin/bash

# deploy_debian_vm.sh - deploys a single Debian VM from template2.json

read -sp "Enter the admin password for the VM (min 12 chars, upper/lowercase and numbers): " ADMIN_PASSWORD
echo

RESOURCE_GROUP="virtualmachines-rg"
LOCATION="eastus"
TEMPLATE_FILE="template2.json"
VM_NAME="vm-debian"

# Create resource group if it does not exist

az group create 
--name $RESOURCE_GROUP 
--location $LOCATION 
-o none

echo "Deploying Debian VM..."

# Deploy ARM template

az deployment group create 
--resource-group $RESOURCE_GROUP 
--template-file $TEMPLATE_FILE 
--parameters adminPassword=$ADMIN_PASSWORD 
--parameters adminUsername=azureuser 
--parameters location=$LOCATION 
-o table

# Show deployed VM

echo -e "\nVM deployed:"
az vm show 
--resource-group $RESOURCE_GROUP 
--name $VM_NAME 
-d 
-o table

# Show NICs

echo -e "\nNetwork Interfaces:"
az network nic list 
--resource-group $RESOURCE_GROUP 
-o table

# Show private IP

echo -e "\nPrivate IP of VM:"
az vm list-ip-addresses 
--resource-group $RESOURCE_GROUP 
--name $VM_NAME 
-o table

