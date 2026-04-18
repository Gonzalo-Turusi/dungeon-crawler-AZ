# Azure Depths

**Azure Depths** is an AI-powered text dungeon crawler: players descend procedural floors, fight and loot, and read narrated outcomes—backed by Azure OpenAI, serverless APIs, and durable data on Azure. This repository is a **portfolio reference** that pairs a multi-service Azure architecture with a **vertical-slice + CQRS** backend and a modern **Angular** SPA (see `PLAN.md` for the full product and engineering blueprint).

[![Build](https://img.shields.io/badge/build-placeholder-lightgrey.svg)](https://github.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What this demonstrates

- **End-to-end Azure**: Identity, secrets, data, messaging, AI, API surface, static hosting, and observability in one coherent Bicep layout.
- **Security-first defaults**: **Managed identity** for runtime access, **Key Vault** for secrets (including SQL password via `az.getSecret` at deploy time), **RBAC**-enabled vault, no passwords in source control.
- **Scalable patterns**: **Cache-aside** (Redis), **async narration** (Service Bus + Functions), **API Management** in front of HTTP APIs, **Static Web Apps** for the UI.
- **Clean architecture direction**: Vertical slices, **CQRS** (MediatR), and thin Azure Functions as dispatchers—described in detail in `PLAN.md`.

---

## Architecture (high level)

```
                    +------------------+
                    |  Static Web App  |
                    |    (Angular)     |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    |   API Management |
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
              v                             v
     +----------------+            +----------------+
     |  Azure Functions|            |  (Future)      |
     |  (.NET isolated)|            |  HTTP APIs     |
     +--------+-------+            +----------------+
              |
    +---------+---------+
    |                   |
    v                   v
+--------+       +--------------+
|Service |       | Azure OpenAI |
|  Bus   |       |  (narration) |
+---+----+       +--------------+
    |
    v
+--------+
|Narrator|
|Function|
+--------+

Data plane (simplified):

  +------+     +-------+     +-------------+
  | SQL  |     | Redis |     |Blob Storage |
  | DB   |     | Cache |     | (exports)   |
  +------+     +-------+     +-------------+
       ^            ^
       |            |
       +-----+------+
             |
      +------+------+
      | Key Vault   |
      | (secrets,   |
      |  conn strs) |
      +------+------+
             ^
             |
      +------+------+
      | User-assigned|
      | + Function   |
      |   system MI  |
      +-------------+

Telemetry: Application Insights
Governance: Azure Policy (optional), budgets (optional)
```

---

## Tech stack

| Layer | Technologies |
|--------|----------------|
| **Backend** | .NET 10, C# 14, ASP.NET Core Minimal APIs, Azure Functions (isolated worker, .NET 10), EF Core 10, MediatR (CQRS) |
| **Frontend** | Angular 21 (zoneless, Signals, standalone components), TypeScript, Vitest |
| **Infrastructure** | Bicep, Azure CLI, PowerShell |
| **AI** | Azure OpenAI |
| **Data** | Azure SQL (serverless GP), Azure Cache for Redis, Azure Blob Storage |
| **Messaging** | Azure Service Bus |
| **Security & ops** | Key Vault (RBAC), Managed identities, API Management, Application Insights |

*Application source layout for API, Functions, and Angular is specified in `PLAN.md`; this repo currently includes the **infrastructure scaffold** and bootstrap scripts as the deployable baseline.*

---

## Azure services used

| Service | Why it is here |
|--------|----------------|
| **Resource Group** | Logical boundary for all Depths resources and deployments. |
| **User-assigned managed identity** | Stable identity for workloads that need Key Vault and Azure RBAC without secrets in code. |
| **Key Vault (RBAC)** | Stores SQL password and connection material; deploy-time `az.getSecret` and runtime secret access. |
| **Application Insights** | Centralized telemetry for APIs and Functions. |
| **Azure OpenAI** | Narration and in-game text generation. |
| **Azure SQL + DB** | Authoritative game state, runs, leaderboard, narrative log. |
| **Storage accounts** | Durable blobs (e.g. exports) and Functions host storage. |
| **Azure Cache for Redis** | Cache-aside for hot reads and session-scale data. |
| **Service Bus** | Decouples game actions from narration and other async work. |
| **Azure Functions** | Event-driven narrators and command/query handlers (isolated .NET). |
| **API Management** | Front door for HTTP APIs, policies, and future throttling/auth. |
| **Static Web Apps** | Hosts the Angular SPA at the edge. |
| **Azure Policy (optional)** | Enforces tagging and governance on the resource group. |
| **Cost management / budgets (optional)** | Subscription or RG budgets with email alerts. |

---

## Getting started

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`), logged in (`az login`)
- [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) (`pwsh`)
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) (often via `az bicep install`)
- Permissions: ability to create resource groups, deploy templates, and (for step 3) assign RBAC and write Key Vault secrets—or a teammate who can grant them

### 1. Configure parameters

1. Copy `infra/prod.bicepparam.example` to `infra/prod.bicepparam` (the latter is **gitignored**).
2. Edit `infra/prod.bicepparam`: set `YOUR_SUBSCRIPTION_ID`, `YOUR_RESOURCE_GROUP_NAME`, and `YOUR_KEYVAULT_NAME` in the `az.getSecret(...)` call to match your environment after deployment (Key Vault name follows the naming convention in Bicep; use the portal or deployment outputs to confirm).

### 2. Bootstrap — steps 1 and 2 (RG + Bicep deploy)

From the **repository root**:

```powershell
pwsh ./infra/scripts/bootstrap-step1-step2.ps1 `
  -SubscriptionId "<your-subscription-guid>" `
  -ResourceGroupName "<your-resource-group>" `
  -BudgetContactEmail "<your-alert-email>" `
  -PolicyDefinitionId "/providers/Microsoft.Authorization/policyDefinitions/<definition-id>"
```

Omit budget or policy if you are iterating:

```powershell
pwsh ./infra/scripts/bootstrap-step1-step2.ps1 `
  -SubscriptionId "<your-subscription-guid>" `
  -ResourceGroupName "<your-resource-group>" `
  -SkipBudget `
  -SkipPolicy
```

This creates the resource group (with tags), optionally RG budget and policy assignment, then runs `az deployment group create` with `infra/main.bicep` and `infra/prod.bicepparam`.

### 3. Bootstrap — step 3 (Key Vault secret, Function MI, RBAC)

After infrastructure exists, set the SQL admin password secret and wire Function App managed identity and RBAC:

```powershell
pwsh ./infra/scripts/bootstrap-step3.ps1 `
  -SubscriptionId "<your-subscription-guid>" `
  -ResourceGroupName "<your-resource-group>" `
  -SqlAdminPasswordSecretValue '<strong-password-from-secure-channel>' `
  -BudgetAlertEmail '<your-email>'
```

- Use `-GrantCurrentUserKeyVaultAccess` if you need the script to assign **Key Vault Secrets Officer** to your user for RBAC vaults.
- Use `-SkipBudget` to skip subscription-level budget creation.
- Align `-Org`, `-App`, `-Env`, regions, and `-Instance` with `prod.bicepparam` if you changed naming defaults.

See `infra/README-step1-step2.md` for additional context.

### 4. Build ARM from Bicep (optional)

If you maintain `infra/main.json` alongside Bicep:

```powershell
az bicep build --file infra/main.bicep
```

---

## Architecture decisions

- **Vertical slice + CQRS**: Features are grouped by capability; MediatR commands/queries keep domain logic out of Functions and Minimal API endpoints (see `PLAN.md`).
- **Cache-aside**: Redis reduces load on SQL for read-heavy or derived state while keeping the database authoritative.
- **Managed identity everywhere (runtime)**: Functions and supported resources use Azure AD auth to Key Vault and data-plane RBAC where applicable—no static keys in app settings for those paths.
- **No hardcoded secrets**: SQL password lives in Key Vault; `prod.bicepparam` uses `az.getSecret` only with IDs you fill locally in a **gitignored** file.

---

## Repository layout (infra focus)

```
infra/
  main.bicep              # Entry module
  main.json               # Compiled ARM (optional artifact)
  prod.bicepparam.example # Template for deploy parameters
  modules/                # identity-security, data, messaging, compute-edge
  scripts/
    bootstrap-step1-step2.ps1
    bootstrap-step3.ps1
```

---

## Badges

Replace the placeholder build badge above with your pipeline (GitHub Actions, Azure DevOps, etc.) once CI is connected.

---

## License

This project is licensed under the [MIT License](LICENSE).
