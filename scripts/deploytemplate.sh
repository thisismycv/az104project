#!/bin/bash

RESOURCE_GROUP="virtualmachines-rg"
DEPLOYMENT_NAME="template"
TEMPLATE_FILE="template.json"
LOCATION="eastus"

echo "Validando template..."
az deployment group validate \
  --resource-group $RESOURCE_GROUP \
  --template-file $TEMPLATE_FILE \

echo "Iniciando deployment en el grupo de recursos $RESOURCE_GROUP..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --template-file $TEMPLATE_FILE \

echo "Deployment completado. Listando VMs en $RESOURCE_GROUP (si no hay VMs, la tabla estará vacía):"
az vm list -g $RESOURCE_GROUP -o table

echo "Listando NSGs creados:"
az network nsg list -g $RESOURCE_GROUP -o table

echo "Listando subnets de la VNet example-vnet:"
az network vnet subnet list -g $RESOURCE_GROUP --vnet-name example-vnet -o table

