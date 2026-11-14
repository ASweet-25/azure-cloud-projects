# 01 — Azure Resource Groups and Tags

**Status:** In progress. Deployment, tag validation, and cleanup have not yet been confirmed. Scripts are provided for the learner to run; no Azure execution is claimed.

## Business scenario and objective

Prepare a dedicated container for an IT training environment. Apply ownership and environment labels so future resources can be organized and reviewed consistently. Demonstrate subscription selection, Azure CLI use, tagging, and verified teardown.

A resource group is like a project folder; tags are labels on that folder. It is not an Active Directory group, and resource-group tags do not automatically propagate to resources.

| Scope | Configuration |
|---|---|
| Subscription | Your selected lab subscription |
| Dedicated resource group | `rg-azlab-foundations-01` |
| Group metadata location | `eastus` |
| Tags | `Owner=Anthony Environment=Lab Project=AzureFoundations` |
| Workloads | None |

The group's location stores group metadata; resources added later can have their own locations.

## Prerequisites

An Azure subscription, permission to create/tag/delete resource groups, and Azure CLI. Use Azure Portal Cloud Shell **Bash** with **No storage account required**, or Bash locally with Azure CLI installed and `az login` completed. Never paste credentials into documentation.

## Run the lab

In Cloud Shell Bash or local Bash:

```bash
git clone https://github.com/ASweet-25/azure-cloud-projects.git
cd azure-cloud-projects
az account list --output table
az account set --subscription "<YOUR-LAB-SUBSCRIPTION-ID>"
az account show --query "{Name:name,Subscription:id}" --output table

bash projects/01-resource-groups-and-tags/scripts/deploy.sh "<YOUR-LAB-SUBSCRIPTION-ID>"
bash projects/01-resource-groups-and-tags/scripts/validate.sh "<YOUR-LAB-SUBSCRIPTION-ID>"
```

Expected deployment result: group provisioning state `Succeeded`. Validation checks the location, required tags, and absence of workloads. The deployment script refuses to modify an existing group with this name.

## Independent challenge

In the portal, add `CostCenter=Training` to the group's tags. Run validation again and inspect the printed tags. Explain why adding a tag does not grant access.

## Troubleshooting

| Symptom | Investigation |
|---|---|
| AuthorizationFailed | Confirm the subscription and ask the subscription administrator to review your permitted scope. |
| Group name already exists | Inspect it; use another dedicated name consistently instead of changing shared resources. |
| Validation fails | Inspect group location/tags; extra resources are deliberately rejected by this empty-group lab. |
| Deletion fails | Check locks, permissions, and the CLI error. Do not delete unrelated locks or resources. |

## Security and cost decisions

No workloads, credentials, role assignments, or public endpoints are created. Use only a dedicated training group. An empty group has no workload runtime; this lab does not deploy compute, storage, logs, backup, or networking resources. Existing subscriptions/resources can still incur costs.

Use ephemeral Cloud Shell to avoid provisioning shell storage. Its files disappear when the session ends; commit approved evidence before ending it. A $100 monthly lab budget is a planning target, not a hard spending limit. Budget notifications can be delayed and do not stop resources automatically. Before future paid projects, review active labs and configure Cost Management budget alerts.

## Evidence and completion

Use [evidence.md](evidence.md) to record actual results. Redact subscription/tenant IDs, account details, and other sensitive information before publishing screenshots. Do not upload raw account exports.

After evidence is recorded, run cleanup:

```bash
bash projects/01-resource-groups-and-tags/scripts/cleanup.sh "<YOUR-LAB-SUBSCRIPTION-ID>"
```

The script displays the selected subscription and exact group, refuses to delete nonempty groups, requires the group name as confirmation, waits for deletion, and verifies absence. It removes only this empty group. No backup or soft-delete resources are created by this lab. Existing shell storage, other groups, budgets, and subscription-level objects are outside its scope; review those separately. Billing information may arrive later.

## Reflection and interview practice

1. How do subscriptions and resource groups differ?
2. What does a tag do?
3. Why verify subscription context before deletion?
4. Where would you investigate an authorization failure?
5. Why does a budget alert not guarantee a spending cap?

Explain the scenario, the checks you performed, and your actual outcome. Resume accomplishments and a website case study should be written only after evidence is available.

## Official references

- [Resource group CLI reference](https://learn.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest)
- [Ephemeral Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/get-started/ephemeral)
