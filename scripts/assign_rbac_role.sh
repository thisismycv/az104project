#!/bin/bash
set -e

# ----------- Parameters -----------
ROLE_NAME="$1"
USER_LIST="$2"
SCOPE="$3"  # subscription, resource group, or resource

if [ -z "$ROLE_NAME" ] || [ -z "$USER_LIST" ] || [ -z "$SCOPE" ]; then
  echo "Usage: $0 <Role Name> <User UPNs comma-separated> <Scope>"
  echo "Example: $0 'Owner' 'user1@domain.com,user2@domain.com' '/subscriptions/<subscription-id>'"
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

  # Check if the user already has the role at this scope
  EXISTING=$(retry az role assignment list --assignee "$USER_ID" --scope "$SCOPE" --query "[?roleDefinitionName=='$ROLE_NAME'].id" -o tsv)
  if [ -n "$EXISTING" ]; then
    echo "ℹ️ User '$USER' already has role '$ROLE_NAME' at scope '$SCOPE'. Skipping."
    continue
  fi

  # Assign the role
  echo "➕ Assigning role '$ROLE_NAME' to '$USER' at scope '$SCOPE'..."
  retry az role assignment create --assignee "$USER_ID" --role "$ROLE_NAME" --scope "$SCOPE"
  echo "✅ Successfully assigned '$ROLE_NAME' to '$USER'"
done
