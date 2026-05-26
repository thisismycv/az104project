#!/bin/bash
POLICYNAME="$1"
DESCRIPTION="$2"
TAGNAME="$3"

if [[ -z "$POLICYNAME" || -z "$DESCRIPTION" || -z "$TAGNAME" ]]; then
    echo "Uso: $0 <policy-name> <description> <tag-name>"
    exit 1
fi

az policy definition create \
    --name "$POLICYNAME" \
    --display-name "$POLICYNAME" \
    --description "$DESCRIPTION" \
    --rules policytags.json \
    --params "{\"tagName\":{\"type\":\"String\",\"metadata\":{\"displayName\":\"Tag Name\",\"description\":\"Name of the tag\"}}}" \
    --mode All