# Azure Depths — Text Dungeon Crawler on Azure (.NET 10 + Angular 21)

## Project Context
I am learning Azure from scratch over 2 days. The goal is to build a
real project with production-ready architecture, proper security practices,
and hands-on experience with as many Azure services as possible.
The chosen theme is a text-based dungeon crawler with AI-generated narration.

## The Game — "Azure Depths"
A text-based dungeon crawler where the player descends floors of a dungeon.
Each action is sent to the backend, processed with real business rules,
and Azure OpenAI narrates the result. Real permadeath: on death, the run
ends and is archived to the global leaderboard.

**Game loop:**
1. Player arrives at a floor → OpenAI describes the scene
2. Player chooses an action (explore / fight / flee / use item)
3. Backend processes rules (damage, loot, traps, death)
4. Message goes to Service Bus → NarratorFunction calls OpenAI
5. Response is saved to SQL and returned to the frontend
6. Next floor or death (permadeath)

**Features:**
- Create a character with a class: warrior, mage, or rogue
  (affects prompts and stats)
- Floor events: combat, trap, merchant, rest, boss every 5 floors
- Inventory of up to 4 items with real stat effects
- Permadeath: on death, run is archived to the leaderboard
- Global leaderboard: floors cleared, monsters killed
- Full run history saved and readable as a narrative log
- Export full run as JSON to Blob Storage
- **Bilingual support (English / Spanish)**: the game UI and OpenAI
  narration must support both languages. The player selects their
  language on character creation. The selected language is stored in
  the Run entity and passed to every OpenAI prompt so narration is
  always in the player's chosen language.

## Tech Stack

### Backend — .NET 10 (LTS, supported until November 2028)
Actively use the latest .NET 10 and C# 14 improvements throughout
the code. Do not fall back to older patterns when a newer equivalent
exists:

- **Built-in Minimal API validation**: use AddValidation() and
  [Required], [Range] attributes directly on endpoints.
  No FluentValidation, no custom validation middleware.
- **C# 14 Extension Members**: use extension properties and static
  extension members to keep domain logic clean.
- **C# 14 field keyword**: use in properties that need minimal
  validation logic, avoiding unnecessary private fields.
- **C# 14 null-conditional assignment**: use customer?.Property = value
  wherever it simplifies null-safe assignments.
- **C# 14 partial constructors**: use where compatible with source
  generators (EF Core, DI).
- **Built-in OpenAPI 3.1**: use WithOpenApi() natively. No Swashbuckle.
- **EF Core 10 named query filters**: filter active vs archived runs
  without repeating conditions on every query.
- **EF Core 10 complex type / JSON column support**: for player
  inventory state.
- **Azure Functions isolated worker model on .NET 10**
- **MediatR**: for CQRS — every Function triggers a Command or Query,
  nothing else. Functions are thin dispatchers only.
- **TypeScript 6.0** on the frontend (required by Angular 21)

### Frontend — Angular 21 (v21.2.9, latest stable as of April 2026)
Actively use all Angular 21 modern features. Do not use deprecated
or legacy patterns when a modern equivalent exists:

- **Zoneless change detection**: do NOT include zone.js. Angular 21
  removes it from the boilerplate by default. All reactivity via Signals.
- **Signals for all game state**: use signal(), computed(), effect()
  for HP, current floor, inventory, and the narration log.
  No BehaviorSubject or ngOnChanges where Signals suffice.
- **Signal Forms (experimental)**: use the new form() API for the
  character creation form.
- **Standalone components only**: no NgModules anywhere.
- **OnPush on all components**: combined with zoneless for maximum
  rendering performance.
- **Vitest as the test runner**: default in Angular 21. No Karma.
- **ngx-translate for i18n**: runtime language switching without page
  reload. OpenAI prompts include the selected language so narration
  matches.
- **TailwindCSS**: for fast styling without custom CSS overhead.
- **Terminal-style UI**: typewriter effect for narration text, dark
  color palette, monospace font.

### Infrastructure
- **Bicep** for all Azure resources (IaC)
- **Azure Static Web Apps** for frontend deployment

## Azure Services and Their Exact Role
| Service | Role |
|---|---|
| Azure Functions (.NET 10) | Entire backend |
| API Management (Consumption tier) | Gateway, rate limiting, JWT validation |
| Azure Entra ID | User auth, JWT tokens, OAuth2 PKCE |
| Service Bus (Basic tier) | Decouple player action → AI narration |
| Azure OpenAI (GPT-4o mini) | Dungeon narrator |
| Azure SQL (Serverless, 1h autopause) | Game state, history, leaderboard |
| Azure Cache for Redis (Basic C0) | Application cache (see cache strategy below) |
| Blob Storage | JSON run exports |
| Key Vault | All secrets |
| App Insights | Logs, traces, OpenAI latency |
| Static Web Apps (Free tier) | Angular deployment |
| Synapse Analytics | Separate analytics flow (see below) |

## Cache Strategy — Azure Cache for Redis (Basic C0)
Use the Cache-Aside pattern throughout. Every read goes to Redis first;
on a miss, read from SQL, populate Redis, then return.

| What | TTL | Why |
|---|---|---|
| Active run state | 5 min | Most-read data — queried before every action |
| Global leaderboard | 2 min | Expensive join query, does not need real-time |
| Player profile | 10 min | Read on every auth request, rarely changes |
| Floor event config | 1 hour | Semi-static configuration data |

**Cache invalidation rules:**
- On ExecuteAction → invalidate run state cache for that runId
- On run death → invalidate run state + leaderboard cache
- On player update → invalidate player profile cache

Cache keys follow the pattern: `{entity}:{id}` — e.g. `run:abc123`,
`player:xyz789`, `leaderboard:global`

All Redis access is encapsulated in `/Infrastructure/Cache/` —
handlers never call Redis directly, they go through a typed cache
service. This makes it easy to mock in tests and swap implementations.

## Backend Architecture — Vertical Slice + CQRS with MediatR
Each feature is a self-contained slice. Every Azure Function is a thin
dispatcher that sends a Command or Query through MediatR and returns
the result. Functions contain zero business logic.

**Pattern per slice:**
HTTP Request
↓
Azure Function (thin dispatcher)
↓
MediatR.Send(Command or Query)
↓
Handler (all logic lives here)
├── Validator (built-in .NET 10 validation attributes)
├── Cache check (Redis) → return if HIT
├── Business logic / domain rules
├── SQL via EF Core 10
└── Cache write on MISS

**Folder structure:**
AzureDepths.Functions/
├── Features/
│   ├── Runs/
│   │   ├── CreateRun/
│   │   │   ├── CreateRunCommand.cs
│   │   │   ├── CreateRunHandler.cs
│   │   │   └── CreateRunValidator.cs
│   │   ├── ExecuteAction/
│   │   │   ├── ExecuteActionCommand.cs
│   │   │   ├── ExecuteActionHandler.cs
│   │   │   └── ExecuteActionValidator.cs
│   │   └── GetRunState/
│   │       ├── GetRunStateQuery.cs
│   │       └── GetRunStateHandler.cs   ← Redis first, SQL on miss
│   ├── Leaderboard/
│   │   └── GetLeaderboard/
│   │       ├── GetLeaderboardQuery.cs
│   │       └── GetLeaderboardHandler.cs ← Redis TTL 2 min
│   └── Narrator/
│       └── NarrateAction/
│           ├── NarrateActionCommand.cs
│           └── NarrateActionHandler.cs  ← Service Bus trigger → OpenAI
├── Infrastructure/
│   ├── Data/              # EF Core 10 DbContext + Migrations
│   ├── Cache/             # Typed Redis service (Cache-Aside)
│   ├── OpenAI/            # OpenAI client wrapper
│   └── ServiceBus/        # Message publisher
├── Domain/
│   ├── Entities/          # Run, Player, Item, Leaderboard
│   └── Enums/             # RunStatus, CharacterClass, Language, FloorEvent
└── Program.cs             # DI, MediatR, EF Core, Redis, App Insights

## Security — Critical Learning Objective
Everything must follow a production-grade security model. Never simplify
by hardcoding secrets or skipping auth layers:

- **System-assigned Managed Identity** on every Function App — Azure
  creates and rotates credentials automatically. No passwords in code.
- **Granular RBAC** — each service has exactly the minimum permissions
  it needs. Example: Key Vault Secrets Reader but NOT Key Vault Admin.
- **Key Vault accessed only via Managed Identity** — never via connection
  strings in code, plain-text environment variables, or appsettings.json
  with secrets. Redis connection string also lives in Key Vault.
- **Entra ID App Registration** for the Angular frontend using the
  OAuth2 PKCE flow — the most secure option for SPAs.
- **APIM validating JWT** before any request reaches a Function —
  validate-jwt policy applied on all routes.
- **Azure SQL with Entra Authentication** — the Function connects to
  the database using its Managed Identity. No username/password.
- **Redis connection secured via Key Vault** — connection string fetched
  at startup via Managed Identity, never hardcoded.

**Full security flow:**
[Angular] → PKCE login with Entra ID → receives JWT
↓
[APIM] → validates JWT against Entra ID → allows through
↓
[Function] → Managed Identity → fetches secrets from Key Vault
↓                                  ↓
[Redis] ← cache-aside             [Key Vault secrets]
↓
[SQL / Service Bus / OpenAI / Blob] ← all via Managed Identity

If a connection string appears hardcoded anywhere in the codebase,
treat it as an architecture error, not an acceptable shortcut.

## Synapse Analytics — Separate Learning Flow
Synapse is expensive if left running, so it lives in a separate,
optional flow. The goal is to understand the theory and use it for
a maximum of 1 hour.

**Implement as a standalone /analytics folder, separate from the game:**
- A Data Factory pipeline that copies data from Azure SQL → Synapse
  (simulates a real ETL / data migration)
- Analytical queries in Synapse: top runs, death patterns by floor,
  most successful class
- README with theory: when to use Synapse vs regular SQL, differences
  between dedicated pool vs serverless, real production use cases,
  and how Synapse fits into data migration and transformation workflows
- The Synapse resource is created and destroyed with a single separate
  Bicep command to avoid unnecessary costs

## Data Model (EF Core 10)
```csharp
Player      { Id, EntraId, Username, CreatedAt }
Run         { Id, PlayerId, Class, Language, CurrentFloor, Hp, MaxHp,
              Gold, Status (active/dead/abandoned), StartedAt, EndedAt }
RunAction   { Id, RunId, Floor, ActionType, PlayerInput,
              NarratorResponse, Timestamp }
Item        { Id, RunId, Name, Effect, Slot }           // JSON column
Leaderboard { RunId, PlayerId, Username, FloorsCleared,
              MonstersKilled, DiedAt }
```

Use EF Core 10 Migrations to version the schema. Include basic seed
data. Use named query filters to separate active from archived runs.
Store the Item collection as a JSON column on the Run entity using
EF Core 10 complex type support.

## Main Endpoints
- POST /runs              → create a new run
- POST /runs/{id}/action  → execute a player action
- GET  /runs/{id}         → current run state (Redis → SQL)
- GET  /runs/{id}/history → full run history as narrative log
- GET  /leaderboard       → global top 10 (Redis → SQL)
- POST /runs/{id}/export  → export run as JSON to Blob Storage

## Cost Constraints — Important
- Azure SQL: serverless tier with 1-hour autopause
- Azure OpenAI: GPT-4o mini, maximum 500 tokens per narration request
- API Management: Consumption tier only
- Azure Cache for Redis: Basic C0 tier (~$16/month, acceptable)
- Static Web Apps: free tier
- Synapse: create only for the learning exercise, cleanup script included
- Set a $15 USD budget alert in the Azure portal
- Hard target: do not exceed $20 USD total

## Expected Folder Structure
azure-depths/
├── infra/
│   ├── main.bicep
│   ├── sql.bicep
│   ├── functions.bicep
│   ├── apim.bicep
│   ├── keyvault.bicep
│   ├── redis.bicep
│   └── analytics/              # Synapse — optional deploy
│       └── synapse.bicep
├── backend/
│   └── AzureDepths.Functions/
│       ├── Features/
│       │   ├── Runs/
│       │   │   ├── CreateRun/
│       │   │   ├── ExecuteAction/
│       │   │   └── GetRunState/
│       │   ├── Leaderboard/
│       │   │   └── GetLeaderboard/
│       │   └── Narrator/
│       │       └── NarrateAction/
│       ├── Infrastructure/
│       │   ├── Data/
│       │   ├── Cache/
│       │   ├── OpenAI/
│       │   └── ServiceBus/
│       ├── Domain/
│       │   ├── Entities/
│       │   └── Enums/
│       └── Program.cs
├── frontend/
│   └── src/
│       └── app/
│           ├── auth/
│           ├── game/
│           ├── character/
│           └── leaderboard/
└── analytics/
├── README.md
├── synapse-queries.sql
└── data-factory-pipeline.json

## How We Work Together
We work step by step. I am new to Azure, so every step must include:

1. **Complete, runnable code** for the current step — not snippets,
   actual code that works end to end.
2. **ASCII flow diagram** showing how data moves in that step: which
   service touches what, in what order, and what happens on failure.
3. **Short explanation of WHY** this is done this way in real
   production — what problem it solves, and what would break if
   done differently.
4. **Exact commands** to run and deploy that step.

Start with the Bicep infrastructure setup and the base project
structure. Do not assume anything. Explain every architecture decision.