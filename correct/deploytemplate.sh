#!/bin/bash
# deploytemplate2.sh - despliega template2.json completo

read -sp "Ingrese la contraseña del administrador para la VM (mínimo 12 caracteres, con mayúsculas, minúsculas y números): " ADMIN_PASSWORD
echo

RESOURCE_GROUP="virtualmachines-rg"
LOCATION="eastus"
TEMPLATE_FILE="template2.json"

# Crear grupo de recursos si no existe
az group create --name $RESOURCE_GROUP --location $LOCATION

# Desplegar template
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file $TEMPLATE_FILE \
  --parameters adminPassword=$ADMIN_PASSWORD \
  --parameters adminUsername=azureuser \
  --parameters location=$LOCATION \
  -o table

# Listar VMs creadas
echo -e "\nListando VMs en $RESOURCE_GROUP:"
az vm list --resource-group $RESOURCE_GROUP -o table

# Listar NICs
echo -e "\nListando NICs en $RESOURCE_GROUP:"
az network nic list --resource-group $RESOURCE_GROUP -o table

# Listar NSGs
echo -e "\nListando NSGs en $RESOURCE_GROUP:"
az network nsg list --resource-group $RESOURCE_GROUP -o table

# Listar subnets
echo -e "\nListando subnets de la VNet example-vnet:"
az network vnet subnet list --resource-group $RESOURCE_GROUP --vnet-name example-vnet -o table

