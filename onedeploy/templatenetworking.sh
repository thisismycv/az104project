TEMPLATE_FILE="$1"
PARAMS_FILE="$2"
RG="virtualmachines-rg"

# Si no se pasa archivo de parámetros, usa valores por defecto
if [[ -z "$TEMPLATE_FILE" ]]; then
  echo "Usage: $0 <template.json> [parameters.json]"
  exit 1
fi

# Si PARAMS_FILE está vacío, despliega sin archivo de parámetros
if [[ -z "$PARAMS_FILE" ]]; then
  az deployment group create \
    --resource-group "$RG" \
    --template-file "$TEMPLATE_FILE"
else
  az deployment group create \
    --resource-group "$RG" \
    --template-file "$TEMPLATE_FILE" \
    --parameters @"$PARAMS_FILE"
fi
