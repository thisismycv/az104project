#!/bin/bash
RESOURCE_GROUP="$1"
LOCATION="eastus"
TEMPLATE_FILE="deployvm.json"

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "Uso: $0 <resource-group>"
  exit 1
fi

read -sp "Ingrese la contraseña del administrador para la VM (mínimo 12 caracteres, con mayúsculas, minúsculas y números): " ADMIN_PASSWORD
echo

az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters adminPassword="$ADMIN_PASSWORD" \
  --parameters adminUsername=azureuser \
  --parameters location="$LOCATION" \
  -o table

echo -e "\nListando VMs en $RESOURCE_GROUP:"
az vm list --resource-group "$RESOURCE_GROUP" -o table

echo -e "\nListando NICs en $RESOURCE_GROUP:"
az network nic list --resource-group "$RESOURCE_GROUP" -o table

echo -e "\nListando NSGs en $RESOURCE_GROUP:"
az network nsg list --resource-group "$RESOURCE_GROUP" -o table

echo -e "\nListando subnets de la VNet example-vnet:"
az network vnet subnet list --resource-group "$RESOURCE_GROUP" --vnet-name example-vnet -o table