#/bin/bash
az deployment group delete --resource-group virtualmachines-rg --name template
az deployment group show --resource-group virtualmachines-rg --name template -o table
