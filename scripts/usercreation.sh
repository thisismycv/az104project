#!/bin/bash

set -e  # Exit on any error

DEFAULT_PASSWORD="TempPass123!@#"
TENANT_DOMAIN=$(az rest --method GET --url https://graph.microsoft.com/v1.0/organization \
  --query 'value[0].verifiedDomains[?isDefault].name' -o tsv)

if [ -z "$TENANT_DOMAIN" ]; then
    echo "❌ Could not retrieve tenant domain. Make sure you're logged in to Azure CLI."
    exit 1
fi

echo "→ Tenant Domain: $TENANT_DOMAIN"
echo "Users will be created with password: $DEFAULT_PASSWORD (forced to change on first login)"

# ---------- Input ----------
read -p "Enter username (e.g., john.smith): " USERNAME
read -p "Enter display name (e.g., John Smith): " DISPLAY_NAME

USER_UPN="$USERNAME@$TENANT_DOMAIN"

# ---------- Create User ----------
echo "→ Creating user: $DISPLAY_NAME ($USER_UPN)..."

az ad user create \
  --display-name "$DISPLAY_NAME" \
  --user-principal-name "$USER_UPN" \
  --password "$DEFAULT_PASSWORD" \
  --force-change-password-next-sign-in true \
  --output table

echo "✅ User created successfully: $USER_UPN"

