#!/bin/bash
set -e

# ----------- Parameters -----------
ROLE_NAME="$1"
USER_LIST="$2"

if [ -z "$ROLE_NAME" ] || [ -z "$USER_LIST" ]; then
  echo "Usage: $0 <Role Name> <User UPNs comma-separated>"
  echo "Example: $0 'Global Reader' 'user1@tenant.com,user2@tenant.com'"
  exit 1
fi

# ----------- Retry Function -----------
retry() {
  local n=0
  local max=5
  local delay=3
  until "$@"; do
    n=$((n+1))
    if [ $n -ge $max ]; then
      echo "❌ Command failed after $max attempts: $*"
      return 1
    fi
    echo "⚠️ Retry $n/$max for command: $*"
    sleep $delay
  done
}

# ----------- Resolve Role Template ID -----------
echo "🔍 Getting role template ID for '$ROLE_NAME'..."
ROLE_TEMPLATE_ID=$(retry az rest \
  --method GET \
  --url https://graph.microsoft.com/v1.0/directoryRoleTemplates \
  --query "value[?displayName=='$ROLE_NAME'].id" -o tsv)

if [ -z "$ROLE_TEMPLATE_ID" ]; then
  echo "❌ Role '$ROLE_NAME' not found"
  exit 1
fi

echo "Role template ID: $ROLE_TEMPLATE_ID"

# ----------- Activate Role if Needed -----------
ROLE_ID=$(retry az rest \
  --method GET \
  --url https://graph.microsoft.com/v1.0/directoryRoles \
  --query "value[?roleTemplateId=='$ROLE_TEMPLATE_ID'].id" -o tsv)

if [ -z "$ROLE_ID" ]; then
  echo "⚡ Activating role '$ROLE_NAME'..."
  ROLE_ID=$(retry az rest \
    --method POST \
    --url https://graph.microsoft.com/v1.0/directoryRoles \
    --body "{\"roleTemplateId\":\"$ROLE_TEMPLATE_ID\"}" \
    --query "id" -o tsv)
  echo "Activated role ID: $ROLE_ID"
else
  echo "Role already active. Role ID: $ROLE_ID"
fi

# ----------- Split users into array -----------
IFS=',' read -r -a USERS <<< "$USER_LIST"

# ----------- Assign Role to Each User -----------
for USER in "${USERS[@]}"; do
  USER=$(echo "$USER" | xargs)  # trim spaces
  echo "🔍 Resolving user: $USER"
  
  USER_ID=$(retry az ad user show --id "$USER" --query id -o tsv 2>/dev/null)
  if [ -z "$USER_ID" ]; then
    echo "❌ User '$USER' not found. Skipping."
    continue
  fi

  # ----------- Check membership -----------
  MEMBER_CHECK=$(retry az rest \
    --method GET \
    --url "https://graph.microsoft.com/v1.0/directoryRoles/$ROLE_ID/members" \
    --query "value[?id=='$USER_ID'].id" -o tsv)

  if [ -n "$MEMBER_CHECK" ]; then
    echo "ℹ️ User '$USER' already has role '$ROLE_NAME'. Skipping."
    continue
  fi

  # ----------- Add User to Role -----------
  echo "➕ Adding user '$USER' to role '$ROLE_NAME'..."
  RESPONSE=$(retry az rest \
    --method POST \
    --url "https://graph.microsoft.com/v1.0/directoryRoles/$ROLE_ID/members/\$ref" \
    --body "{\"@odata.id\":\"https://graph.microsoft.com/v1.0/directoryObjects/$USER_ID\"}" \
    -o json 2>&1)

  if echo "$RESPONSE" | grep -q '"error"'; then
    echo "❌ Failed to assign role to '$USER'. Response: $RESPONSE"
  else
    echo "✅ Successfully assigned '$ROLE_NAME' to '$USER'"
  fi
done

