#!/bin/bash

# List deployments and number them
echo "Available deployments in resource group 'virtualmachines-rg':"
mapfile -t deployments < <(az deployment group list --resource-group virtualmachines-rg --query "[].name" -o tsv)

# Print numbered list
for i in "${!deployments[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${deployments[$i]}"
done

# Prompt user for selection by number
echo "Enter the number of the deployment you want to delete:"
read selection

# Validate input
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#deployments[@]}" ]; then
    echo "Invalid selection!"
    exit 1
fi

# Map number to deployment name
deleted="${deployments[$((selection-1))]}"

# Confirm deletion
echo "Deleting deployment: $deleted"
az deployment group delete --resource-group virtualmachines-rg --name "$deleted"

