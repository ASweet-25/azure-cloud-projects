#!/usr/bin/env bash
set -euo pipefail
subscription="${1:?Usage: bash validate.sh <subscription-id>}"
group="rg-azlab-foundations-01"
az account set --subscription "$subscription"
az group show --name "$group" --query '{Name:name,Location:location,State:properties.provisioningState,Tags:tags}' --output json
[[ "$(az group show --name "$group" --query location --output tsv)" == "eastus" ]]
[[ "$(az group show --name "$group" --query properties.provisioningState --output tsv)" == "Succeeded" ]]
for pair in Owner:Anthony Environment:Lab Project:AzureFoundations; do
  key="${pair%%:*}"
  expected="${pair#*:}"
  actual="$(az group show --name "$group" --query "tags.$key" --output tsv)"
  [[ "$actual" == "$expected" ]] || { echo "Tag mismatch: $key" >&2; exit 1; }
done
[[ "$(az resource list --resource-group "$group" --query 'length(@)' --output tsv)" == "0" ]] || {
  echo "Unexpected resources: inspect before cleanup." >&2; exit 1;
}
echo "PASS: required tags, location, provisioning state, and empty-group checks."
