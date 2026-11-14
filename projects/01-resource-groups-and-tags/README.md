# Project 01 — Resource Groups and Tags

**Status: In progress**

## Goal

Learn how to create an Azure resource group, add tags, check the configuration, and delete the group when finished.

A resource group is like a folder for related Azure resources. Tags are labels that help identify their purpose and owner.

## Tools

- Azure Portal
- Azure Cloud Shell — Bash
- Azure CLI

## Lab steps

Open Cloud Shell in the Azure Portal and select **Bash**. Choose **No storage account required** if prompted.

### 1. Check the subscription

```bash
az account show --output table
```

If needed, select your lab subscription:

```bash
az account set --subscription "<YOUR-LAB-SUBSCRIPTION-ID>"
```

### 2. Check the name and create the group

```bash
az group exists --name rg-azlab-foundations-01
```

Continue only if the result is `false`. If the name already exists, choose a different dedicated lab name and use it in every command below.

```bash
az group create \
  --name rg-azlab-foundations-01 \
  --location eastus \
  --tags Owner=Anthony Environment=Lab Project=AzureFoundations
```

### 3. Check the group and tags

```bash
az group show \
  --name rg-azlab-foundations-01 \
  --query "{Name:name,Location:location,State:properties.provisioningState,Tags:tags}" \
  --output json
```

Expected: location `eastus`, state `Succeeded`, and the three tags.

### 4. Clean up

Confirm the correct subscription and check that the lab group is empty:

```bash
az account show --output table
az resource list --resource-group rg-azlab-foundations-01 --output table
```

If the group is empty and belongs to this lab, delete it. Review the group name at the confirmation prompt:

```bash
az group delete --name rg-azlab-foundations-01
az group exists --name rg-azlab-foundations-01
```

Expected final result: `false`.

## My learning notes

To fill in after completing the lab:

- **What I learned:**
- **Any issue I ran into and how I fixed it:**
- **Cleanup result:**
- **Screenshot:** Add a screenshot of the group and tags, with account details hidden.

## Cost note

This lab creates an empty resource group with no paid workloads. Existing resources or Cloud Shell storage can still incur charges. Only delete the dedicated lab group.

## Reference

[Microsoft Learn — Azure resource group commands](https://learn.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest)
