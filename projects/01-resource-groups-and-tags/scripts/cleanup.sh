#!/usr/bin/env bash
set -euo pipefail
subscription="${1:?Usage: bash cleanup.sh <subscription-id>}"
group="rg-azlab-foundations-01"
az account set --subscription "$subscription"
az account show --query '{Name:name,Subscription:id}' --output table
if [[ "$(az group exists --name "$group" --output tsv)" == "false" ]]; then
  echo "Group is already absent."
  exit 0
fi
az group show --name "$group" --query '{Name:name,Location:location,Tags:tags}' --output json
az resource list --resource-group "$group" --output table
[[ "$(az group show --name "$group" --query tags.Project --output tsv)" == "AzureFoundations" ]] || {
  echo "Expected lab tag missing; refusing deletion." >&2; exit 1;
}
[[ "$(az resource list --resource-group "$group" --query 'length(@)' --output tsv)" == "0" ]] || {
  echo "Group is not empty; refusing deletion." >&2; exit 1;
}
read -r -p "To delete only this empty lab group, type $group: " confirmation
[[ "$confirmation" == "$group" ]] || { echo "Cancelled."; exit 1; }
# Do not add resources to the group while cleanup is running.
az group delete --name "$group" --yes
az group wait --name "$group" --deleted
[[ "$(az group exists --name "$group" --output tsv)" == "false" ]] || {
  echo "Deletion not verified." >&2; exit 1;
}
echo "PASS: group absence verified. Review unrelated resources and delayed billing separately."
