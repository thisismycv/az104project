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

# ----------- Get Active Role ID -----------
ROLE_ID=$(retry az rest \
  --method GET \
  --url https://graph.microsoft.com/v1.0/directoryRoles \
  --query "value[?roleTemplateId=='$ROLE_TEMPLATE_ID'].id" -o tsv)

if [ -z "$ROLE_ID" ]; then
  echo "ℹ️ Role '$ROLE_NAME' is not active or has no members. Nothing to remove."
  exit 0
fi
echo "Active Role ID: $ROLE_ID"

# ----------- Split users into array -----------
IFS=',' read -r -a USERS <<< "$USER_LIST"

# ----------- Remove Each User -----------
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

  if [ -z "$MEMBER_CHECK" ]; then
    echo "ℹ️ User '$USER' is not a member of role '$ROLE_NAME'. Skipping."
    continue
  fi

  # ----------- Remove User from Role -----------
  echo "➖ Removing user '$USER' from role '$ROLE_NAME'..."
  RESPONSE=$(retry az rest \
    --method DELETE \
    --url "https://graph.microsoft.com/v1.0/directoryRoles/$ROLE_ID/members/$USER_ID/\$ref" \
    -o json 2>&1)

  if echo "$RESPONSE" | grep -q '"error"'; then
    echo "❌ Failed to remove user '$USER'. Response: $RESPONSE"
  else
    echo "✅ User '$USER' removed from role '$ROLE_NAME'"
  fi
done

