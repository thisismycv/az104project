#/bin/bash
if [ -z "$1" ]; then
  echo "Usage: $0 <user-upn-or-id>"
  exit 1
fi
USER_INPUT="$1"

az group delete \
  --name $USER_INPUT \
  --yes \
  --no-wait

