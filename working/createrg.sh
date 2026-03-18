#!/bin/bash

RESOURCEGROUP="$1"
LOCATION="$2"

az group create \
	--name $RESOURCEGROUP \
	--location $LOCATION
