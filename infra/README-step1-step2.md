# Step 1 and Step 2 Execution Guide

This guide bootstraps the Azure baseline and deploys the Bicep scaffold for Azure Depths.

## What this delivers
- Step 1: baseline resource group, production tags, budget guardrails, basic policy assignment.
- Step 2: modular Bicep scaffold (`main.bicep` + domain modules + `prod.bicepparam`).

## Files
- `infra/main.bicep`
- `infra/prod.bicepparam`
- `infra/modules/identity-security.bicep`
- `infra/modules/data.bicep`
- `infra/modules/messaging.bicep`
- `infra/modules/compute-edge.bicep`
- `infra/scripts/bootstrap-step1-step2.ps1`

## Prerequisites
- Azure CLI installed and logged in (`az login`)
- `Owner` or equivalent RBAC rights on target subscription/resource group
- A policy definition id for required tags (optional at run time if `-SkipPolicy` is used)

## Run
```powershell
pwsh ./infra/scripts/bootstrap-step1-step2.ps1 `
  -SubscriptionId "<subscription-guid>" `
  -BudgetContactEmail "<alerts@company.com>" `
  -PolicyDefinitionId "/providers/Microsoft.Authorization/policyDefinitions/<definition-id>"
```

## Optional flags for iterative setup
```powershell
pwsh ./infra/scripts/bootstrap-step1-step2.ps1 `
  -SubscriptionId "<subscription-guid>" `
  -SkipBudget `
  -SkipPolicy
```

## Naming and regions in this scaffold
- Core region: `brazilsouth`
- AI fallback region: `eastus2`
- Naming convention: `{org}-{app}-{env}-{region}-{service}-{nn}`
