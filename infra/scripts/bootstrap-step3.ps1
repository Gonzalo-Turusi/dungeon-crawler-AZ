# Run from repository root, for example:
#   pwsh ./infra/scripts/bootstrap-step3.ps1 -SqlAdminPasswordSecretValue '<from-secure-channel>'
#   pwsh ./infra/scripts/bootstrap-step3.ps1 -SubscriptionId <sub> -SqlAdminPasswordSecretValue '<secret>' -BudgetAlertEmail you@example.com
# If keyvault secret set returns ForbiddenByRbac, either add -GrantCurrentUserKeyVaultAccess (requires
# permission to create role assignments, e.g. Owner) or ask an admin for "Key Vault Secrets Officer" on the vault.
#
# Step 3 - Security hardening: Key Vault secret for SQL admin password, Function App Managed Identity,
# RBAC (Service Bus, OpenAI, Storage, RG Reader, Key Vault Secrets User), optional subscription budget.
# Uses Azure CLI only (no Bicep/ARM from this script).

param(
    [string]$SubscriptionId = "YOUR_SUBSCRIPTION_ID",
    [string]$ResourceGroupName = "YOUR_RESOURCE_GROUP_NAME",
    [string]$Org = "dga",
    [string]$App = "azdepths",
    [string]$Env = "prod",
    [string]$CoreRegion = "brazilsouth",
    [string]$AiRegion = "eastus2",
    [int]$Instance = 1,
    [string]$SqlAdminPasswordSecretName = "sql-admin-password",
    [Parameter(Mandatory = $true, HelpMessage = "SQL admin password to store in Key Vault. Do not commit this value; pass at runtime or from a secure store.")]
    [string]$SqlAdminPasswordSecretValue,
    [string]$BudgetName = "azdepths-prod-subscription-budget",
    [decimal]$BudgetAmountUsd = 15,
    # Use a real address, or leave '$ALERT_EMAIL' / empty to be prompted; empty response skips the budget.
    [string]$BudgetAlertEmail = '$ALERT_EMAIL',
    # Optional: use when `az login` must target a specific directory (see AADSTS50132 / invalid_grant errors).
    [string]$AzureTenantId = "",
    # Grants the signed-in user "Key Vault Secrets Officer" on the vault so az keyvault secret set works (RBAC vault).
    [switch]$GrantCurrentUserKeyVaultAccess,
    [switch]$SkipBudget
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-LastExitCode {
    param([string]$StepName)
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed at step: $StepName (exit code: $LASTEXITCODE)"
    }
}

function Assert-AzCli {
    az --version | Out-Null
    Assert-LastExitCode -StepName "Assert-AzCli"
}

function Assert-AzLoggedIn {
    param([string]$TenantIdHint)

    az account show --query id -o tsv | Out-Null
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "Azure CLI is not signed in, or the session/token expired (often AADSTS50132 / invalid_grant)."
    Write-Host "Re-authenticate, then run this script again."
    Write-Host ""
    Write-Host "  az logout"
    if (-not [string]::IsNullOrWhiteSpace($TenantIdHint)) {
        Write-Host ('  az login --tenant "' + $TenantIdHint + '" --scope "https://management.core.windows.net//.default"')
    }
    else {
        Write-Host '  az login --scope "https://management.core.windows.net//.default"'
        Write-Host "  # If your org uses a specific directory, add: -AzureTenantId <tenant-guid> and use:"
        Write-Host '  # az login --tenant "<tenant-guid>" --scope "https://management.core.windows.net//.default"'
    }
    Write-Host ""
    throw "Azure CLI authentication required. Run the commands above, then retry."
}

function Set-SubscriptionContext {
    param([string]$SubId)
    if (-not [string]::IsNullOrWhiteSpace($SubId)) {
        az account set --subscription $SubId
        Assert-LastExitCode -StepName "Set-SubscriptionContext"
    }
}

function Get-BicepTake {
    param(
        [string]$Text,
        [int]$MaxLen
    )
    if ($Text.Length -le $MaxLen) { return $Text }
    return $Text.Substring(0, $MaxLen)
}

function Get-DepthsComputedNames {
    param(
        [string]$Org,
        [string]$App,
        [string]$Env,
        [string]$CoreRegion,
        [string]$AiRegion,
        [int]$Instance
    )

    $regionShortMap = @{
        brazilsouth = "brs"
        eastus2     = "eus2"
    }

    $coreKey = $CoreRegion.ToLowerInvariant()
    $aiKey = $AiRegion.ToLowerInvariant()

    $coreRegionShort = $regionShortMap[$coreKey]
    if (-not $coreRegionShort) {
        $coreRegionShort = $CoreRegion.Replace(" ", "").ToLowerInvariant()
    }

    $aiRegionShort = $regionShortMap[$aiKey]
    if (-not $aiRegionShort) {
        $aiRegionShort = $AiRegion.Replace(" ", "").ToLowerInvariant()
    }

    $sequence = $Instance.ToString().PadLeft(2, "0")
    $namePrefix = "$Org-$App-$Env-$coreRegionShort"
    $modulePrefix = "$Org-$App-$Env"

    $kvCollapsed = ($modulePrefix + $namePrefix) -replace "-", ""
    $keyVaultStem = Get-BicepTake -Text $kvCollapsed -MaxLen 16
    $keyVaultName = ("$keyVaultStem" + "kv" + $sequence).ToLowerInvariant() -replace "_", ""

    $dataCollapsed = ("${namePrefix}data") -replace "-", ""
    $dataStem = Get-BicepTake -Text $dataCollapsed -MaxLen 18
    $dataStorageAccountName = ("$dataStem" + "st" + $sequence).ToLowerInvariant()

    return [pscustomobject]@{
        Sequence              = $sequence
        NamePrefix            = $namePrefix
        ModulePrefix          = $modulePrefix
        KeyVaultName          = $keyVaultName
        FunctionAppName       = "$modulePrefix-func-$sequence"
        ServiceBusNamespace   = "$Org-$App-$Env-sb-$sequence"
        DataStorageAccount    = $dataStorageAccountName
        AzureOpenAiAccount    = "$modulePrefix-$aiRegionShort-aoai-$sequence"
        AiRegionShort         = $aiRegionShort
    }
}

function Confirm-AzResourceInGroup {
    param(
        [string]$ResourceGroupName,
        [string]$ResourceName,
        [string]$StepName
    )

    $id = az resource list `
        --resource-group $ResourceGroupName `
        --name $ResourceName `
        --query "[0].id" -o tsv
    Assert-LastExitCode -StepName "resource list ($StepName)"

    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Resource not found in group '$ResourceGroupName': $ResourceName ($StepName)"
    }
    return $id.Trim()
}

function Get-FunctionAppPrincipalId {
    param(
        [string]$ResourceGroupName,
        [string]$FunctionAppName
    )

    $principalId = az functionapp identity show `
        --resource-group $ResourceGroupName `
        --name $FunctionAppName `
        --query principalId -o tsv 2>$null

    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return $principalId.Trim()
}

function Ensure-SystemAssignedIdentity {
    param(
        [string]$ResourceGroupName,
        [string]$FunctionAppName
    )

    Write-Host "Checking system-assigned managed identity on Function App '$FunctionAppName'..."
    $principalId = Get-FunctionAppPrincipalId -ResourceGroupName $ResourceGroupName -FunctionAppName $FunctionAppName

    if ([string]::IsNullOrWhiteSpace($principalId)) {
        Write-Host "Enabling system-assigned managed identity..."
        az functionapp identity assign --resource-group $ResourceGroupName --name $FunctionAppName | Out-Null
        Assert-LastExitCode -StepName "functionapp identity assign"

        $principalId = Get-FunctionAppPrincipalId -ResourceGroupName $ResourceGroupName -FunctionAppName $FunctionAppName
        if ([string]::IsNullOrWhiteSpace($principalId)) {
            throw "Managed identity enabled but principalId is still empty."
        }
    }
    else {
        Write-Host "System-assigned identity already present (principalId present)."
    }

    return $principalId
}

function Test-RoleAssignmentExists {
    param(
        [string]$PrincipalId,
        [string]$RoleName,
        [string]$Scope
    )

    $roleQuery = "[?roleDefinitionName=='" + $RoleName + "'].id"
    $matches = az role assignment list `
        --assignee $PrincipalId `
        --scope $Scope `
        --query $roleQuery `
        -o tsv

    Assert-LastExitCode -StepName "role assignment list ($RoleName on scope)"
    return -not [string]::IsNullOrWhiteSpace($matches)
}

function Ensure-RoleAssignment {
    param(
        [string]$PrincipalId,
        [string]$RoleName,
        [string]$Scope,
        [string]$Description,
        [ValidateSet("ServicePrincipal", "User")]
        [string]$AssigneePrincipalType = "ServicePrincipal"
    )

    if (Test-RoleAssignmentExists -PrincipalId $PrincipalId -RoleName $RoleName -Scope $Scope) {
        Write-Host "RBAC skip (already assigned): $Description - $RoleName"
        return
    }

    Write-Host "RBAC assign: $Description - $RoleName"
    az role assignment create `
        --assignee-object-id $PrincipalId `
        --assignee-principal-type $AssigneePrincipalType `
        --role $RoleName `
        --scope $Scope | Out-Null
    Assert-LastExitCode -StepName "role assignment create ($RoleName)"
}

function Invoke-BudgetSection {
    param(
        [string]$BudgetName,
        [decimal]$Amount,
        [string]$AlertEmail,
        [bool]$ShouldCreate
    )

    Write-Host ""
    Write-Host "=== Subscription budget ==="

    if (-not $ShouldCreate) {
        Write-Host "Budget creation skipped (no alert email or -SkipBudget)."
        return
    }

    $existing = az consumption budget show --budget-name $BudgetName --query name -o tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existing)) {
        Write-Host "Budget '$BudgetName' already exists on this subscription; skipping create."
        return
    }

    $today = Get-Date
    $startDate = Get-Date -Year $today.Year -Month $today.Month -Day 1
    $endDate = $startDate.AddYears(1).AddDays(-1)

    $escapedEmail = $AlertEmail.Replace('\', '\\').Replace('"', '\"')
    $notificationsJson = '{"actual_GreaterThan80Percent":{"enabled":true,"operator":"GreaterThan","threshold":80,"contactEmails":["' + $escapedEmail + '"]}}'

    Write-Host "Creating subscription budget '$BudgetName' ($Amount USD / month, 80% actual alert)..."
    az consumption budget create `
        --budget-name $BudgetName `
        --category cost `
        --amount $Amount `
        --time-grain monthly `
        --start-date ($startDate.ToString("yyyy-MM-dd")) `
        --end-date ($endDate.ToString("yyyy-MM-dd")) `
        --notifications $notificationsJson
    Assert-LastExitCode -StepName "consumption budget create (subscription scope)"
    Write-Host "Budget created."
}

# --- Main ---

Assert-AzCli
Assert-AzLoggedIn -TenantIdHint $AzureTenantId
Set-SubscriptionContext -SubId $SubscriptionId

Write-Host "Resolving resource names from naming convention (org/app/env/regions/instance)..."
$names = Get-DepthsComputedNames -Org $Org -App $App -Env $Env -CoreRegion $CoreRegion -AiRegion $AiRegion -Instance $Instance

Write-Host "Computed Key Vault:        $($names.KeyVaultName)"
Write-Host "Computed Function App:     $($names.FunctionAppName)"
Write-Host "Computed Service Bus:      $($names.ServiceBusNamespace)"
Write-Host "Computed Data storage:     $($names.DataStorageAccount)"
Write-Host "Computed Azure OpenAI:     $($names.AzureOpenAiAccount)"

Write-Host ""
Write-Host "=== Verify resources in resource group '$ResourceGroupName' ==="
$kvId = Confirm-AzResourceInGroup -ResourceGroupName $ResourceGroupName -ResourceName $names.KeyVaultName -StepName "Key Vault"
$funcId = Confirm-AzResourceInGroup -ResourceGroupName $ResourceGroupName -ResourceName $names.FunctionAppName -StepName "Function App"
$sbId = Confirm-AzResourceInGroup -ResourceGroupName $ResourceGroupName -ResourceName $names.ServiceBusNamespace -StepName "Service Bus"
$stId = Confirm-AzResourceInGroup -ResourceGroupName $ResourceGroupName -ResourceName $names.DataStorageAccount -StepName "Storage account"
$openAiId = Confirm-AzResourceInGroup -ResourceGroupName $ResourceGroupName -ResourceName $names.AzureOpenAiAccount -StepName "Azure OpenAI"

Write-Host "Validating Azure OpenAI is in expected AI region ($AiRegion)..."
$openAiLocation = az cognitiveservices account show `
    --resource-group $ResourceGroupName `
    --name $names.AzureOpenAiAccount `
    --query location -o tsv
Assert-LastExitCode -StepName "cognitive services show"
if ($openAiLocation.Replace(" ", "").ToLowerInvariant() -ne $AiRegion.Replace(" ", "").ToLowerInvariant()) {
    throw "Azure OpenAI account '$($names.AzureOpenAiAccount)' is in '$openAiLocation', expected '$AiRegion'."
}

Write-Host ""
Write-Host "=== Key Vault: SQL admin password secret ==="
if ($GrantCurrentUserKeyVaultAccess) {
    Write-Host "Granting signed-in user 'Key Vault Secrets Officer' on the vault (needed for RBAC-enabled vaults)..."
    $operatorObjectId = az ad signed-in-user show --query id -o tsv
    Assert-LastExitCode -StepName "ad signed-in-user show"
    $operatorObjectId = $operatorObjectId.Trim()
    Ensure-RoleAssignment `
        -PrincipalId $operatorObjectId `
        -RoleName "Key Vault Secrets Officer" `
        -Scope $kvId `
        -Description "Signed-in operator (Key Vault secret migration)" `
        -AssigneePrincipalType User
    Write-Host "Waiting 20s for RBAC propagation before writing the secret (retry the script if set still fails)..."
    Start-Sleep -Seconds 20
}

Write-Host "Setting secret '$SqlAdminPasswordSecretName'..."
az keyvault secret set `
    --vault-name $names.KeyVaultName `
    --name $SqlAdminPasswordSecretName `
    --value $SqlAdminPasswordSecretValue | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Key Vault secret write failed. If the error was ForbiddenByRbac, the vault uses RBAC and your account has no secret-management role."
    Write-Host "Options:"
    Write-Host "  - Re-run with -GrantCurrentUserKeyVaultAccess (you need Microsoft.Authorization/roleAssignments/write on this scope, e.g. Owner or User Access Administrator), or"
    Write-Host "  - Ask a subscription/RG admin to assign you role 'Key Vault Secrets Officer' on vault '$($names.KeyVaultName)'."
    Write-Host ""
    throw "Command failed at step: keyvault secret set (exit code: $LASTEXITCODE)"
}

$secretId = az keyvault secret show `
    --vault-name $names.KeyVaultName `
    --name $SqlAdminPasswordSecretName `
    --query id -o tsv
Assert-LastExitCode -StepName "keyvault secret show"
Write-Host "Secret stored and verified (id: $secretId)."

# Deployments use infra/prod.bicepparam, which resolves sqlAdminPassword via az.getSecret at deploy time.

Write-Host ""
Write-Host "REMINDER: Bicep prod parameters load sqlAdminPassword from Key Vault (see infra/prod.bicepparam)."

Write-Host ""
Write-Host "=== Function App: system-assigned managed identity ==="
$principalId = Ensure-SystemAssignedIdentity -ResourceGroupName $ResourceGroupName -FunctionAppName $names.FunctionAppName
Write-Host "Function App principal (object) id: $principalId"

Write-Host ""
Write-Host "=== RBAC for Function App managed identity ==="
Write-Host "Redis and SQL: no RBAC assignments here; the app resolves connection strings from Key Vault at runtime."

$subscriptionIdResolved = (az account show --query id -o tsv).Trim()
Assert-LastExitCode -StepName "account show"
$rgScope = "/subscriptions/$subscriptionIdResolved/resourceGroups/$ResourceGroupName"

Ensure-RoleAssignment -PrincipalId $principalId -RoleName "Azure Service Bus Data Sender" -Scope $sbId -Description "Service Bus namespace"
Ensure-RoleAssignment -PrincipalId $principalId -RoleName "Azure Service Bus Data Receiver" -Scope $sbId -Description "Service Bus namespace"
Ensure-RoleAssignment -PrincipalId $principalId -RoleName "Cognitive Services OpenAI User" -Scope $openAiId -Description "Azure OpenAI"
Ensure-RoleAssignment -PrincipalId $principalId -RoleName "Storage Blob Data Contributor" -Scope $stId -Description "Data storage account"
Ensure-RoleAssignment -PrincipalId $principalId -RoleName "Reader" -Scope $rgScope -Description "Resource group (baseline)"
Ensure-RoleAssignment -PrincipalId $principalId -RoleName "Key Vault Secrets User" -Scope $kvId -Description "Key Vault (RBAC; get/list secrets)"

Write-Host ""
Write-Host "Step 3 bootstrap completed (Key Vault secret, MI, RBAC)."

# --- Budget (subscription scope; optional / interactive email) ---
$shouldCreateBudget = -not $SkipBudget
$alertEmail = $BudgetAlertEmail

if ($shouldCreateBudget -and ($alertEmail -eq '$ALERT_EMAIL' -or [string]::IsNullOrWhiteSpace($alertEmail))) {
    Write-Host ""
    Write-Host "Budget alert email not set (still '`$ALERT_EMAIL' or empty)."
    $prompt = Read-Host "Enter notification email for the 80% budget alert, or press Enter to skip budget creation"
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        Write-Host "Skipping budget (no email)."
        $shouldCreateBudget = $false
    }
    else {
        $alertEmail = $prompt
    }
}

Invoke-BudgetSection -BudgetName $BudgetName -Amount $BudgetAmountUsd -AlertEmail $alertEmail -ShouldCreate $shouldCreateBudget
