#!/bin/bash

# Check if role name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <Role Name>"
  exit 1
fi

ROLE_NAME="$1"

# List all directory role templates
echo "Available Directory Roles:"
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/directoryRoleTemplates" \
  --query "value[].{Name:displayName,Id:id}" -o table

# Step 1: Get the role template ID
ROLE_TEMPLATE_ID=$(az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/directoryRoleTemplates" \
  --query "value[?displayName=='$ROLE_NAME'].id" \
  -o tsv)

if [ -z "$ROLE_TEMPLATE_ID" ]; then
  echo "Role '$ROLE_NAME' not found."
  exit 1
fi

echo "Role template ID for '$ROLE_NAME': $ROLE_TEMPLATE_ID"

# Step 2: Activate the role if not already activated
ROLE_ID=$(az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/directoryRoles" \
  --query "value[?roleTemplateId=='$ROLE_TEMPLATE_ID'].id" \
  -o tsv)

if [ -z "$ROLE_ID" ]; then
  echo "Activating role '$ROLE_NAME'..."
  ROLE_ID=$(az rest --method POST \
    --url "https://graph.microsoft.com/v1.0/directoryRoles" \
    --body "{\"roleTemplateId\": \"$ROLE_TEMPLATE_ID\"}" \
    --query "id" -o tsv)
fi

echo "Activated/Existing Role ID: $ROLE_ID"

# Step 3: List all users
echo ""
echo "Available Azure AD Users:"
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/users" \
  --query "value[].{DisplayName:displayName,UserPrincipalName:userPrincipalName,ID:id}" \
  -o table
echo ""

# Step 4: Ask user to input multiple User Principal Names (comma-separated)
read -p "Enter User Principal Names (comma-separated) to assign this role to: " USER_LIST

if [ -z "$USER_LIST" ]; then
  echo "No users entered. Exiting."
  exit 1
fi

# Convert comma-separated list into an array
IFS=',' read -r -a USERS <<< "$USER_LIST"

# Step 5: Confirm role assignment
echo ""
echo "Ready to assign role '$ROLE_NAME' to the following users:"
for u in "${USERS[@]}"; do
  echo "- $u"
done

read -p "Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Assignment cancelled."
  exit 0
fi

# Step 6: Assign role to each user
for USER in "${USERS[@]}"; do
  USER=$(echo "$USER" | xargs)  # Trim whitespace

  # Get user object ID
  USER_ID=$(az rest --method GET \
    --url "https://graph.microsoft.com/v1.0/users/$USER" \
    --query "id" -o tsv 2>/dev/null)

  if [ -z "$USER_ID" ]; then
    echo "❌ User '$USER' not found. Skipping."
    continue
  fi

  # Assign role
  RESPONSE=$(az rest --method POST \
    --url "https://graph.microsoft.com/v1.0/directoryRoles/$ROLE_ID/members/\$ref" \
    --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/users/$USER_ID\"}" \
    -o json 2>&1)

  if echo "$RESPONSE" | grep -q '"error"'; then
    echo "❌ Failed to assign role to '$USER'. Response:"
    echo "$RESPONSE"
  else
    echo "✅ Role '$ROLE_NAME' assigned to '$USER'."
  fi
done

