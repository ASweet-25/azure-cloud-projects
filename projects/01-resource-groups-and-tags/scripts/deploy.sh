#!/usr/bin/env bash
set -euo pipefail
subscription="${1:?Usage: bash deploy.sh <subscription-id>}"
group="rg-azlab-foundations-01"
command -v az >/dev/null || { echo "Azure CLI is required." >&2; exit 1; }
az account set --subscription "$subscription"
az account show --query '{Name:name,Subscription:id}' --output table
if [[ "$(az group exists --name "$group" --output tsv)" != "false" ]]; then
  echo "Group already exists; inspect it before choosing a different dedicated name." >&2
  exit 1
fi
az group create --name "$group" --location eastus \
  --tags Owner=Anthony Environment=Lab Project=AzureFoundations
