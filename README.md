# Azure Cloud Projects

Hands-on Azure projects covering infrastructure, security, networking, and automation.

This portfolio documents lab scenarios, reproducible commands, engineering decisions, and validation evidence. Lab work is distinguished from production experience.

## Project index

| Project | Focus | Status |
|---|---|---|
| [01 — Resource Groups and Tags](projects/01-resource-groups-and-tags/README.md) | Azure CLI, organization, tagging, cleanup | In progress — deployment not yet confirmed |

## Working conventions

- Add each project under `projects/NN-project-name/`.
- Include a README, deployment/validation/cleanup instructions, security and cost notes, and sanitized evidence.
- Mark projects complete only after deployment, validation, and cleanup are documented.
- Never commit passwords, tokens, private keys, Terraform state, or sensitive screenshots.
- [Progress tracker](progress.json) records the next checkpoint and assessed skills.

## Work locally

```bash
git clone https://github.com/ASweet-25/azure-cloud-projects.git
cd azure-cloud-projects
git switch -c docs/lab-evidence
# Edit files and add sanitized evidence.
git add projects/01-resource-groups-and-tags
git commit -m "docs: record resource group lab evidence"
git push -u origin docs/lab-evidence
```

Open a pull request to review future changes before merging.
