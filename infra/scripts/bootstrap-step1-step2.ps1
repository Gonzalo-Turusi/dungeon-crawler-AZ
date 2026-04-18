param(
    [string]$SubscriptionId,
    [string]$ResourceGroupName = "YOUR_RESOURCE_GROUP_NAME",
    [string]$Location = "brazilsouth",
    [string]$BudgetName = "azdepths-prod-monthly-budget",
    [decimal]$BudgetAmountUsd = 15,
    [string]$BudgetContactEmail = "",
    [string]$PolicyDefinitionId = "",
    [switch]$SkipBudget,
    [switch]$SkipPolicy
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

function Set-SubscriptionContext {
    param([string]$SubId)
    if (-not [string]::IsNullOrWhiteSpace($SubId)) {
        az account set --subscription $SubId
        Assert-LastExitCode -StepName "Set-SubscriptionContext"
    }
}

function New-AzureDepthsResourceGroup {
    param([string]$RgName, [string]$RgLocation)
    az group create --name $RgName --location $RgLocation --tags `
        Environment=prod Application=azdepths Owner=platform-team `
        CostCenter=cc-0001 DataClass=internal ManagedBy=bicep CountryFocus=colombia
    Assert-LastExitCode -StepName "New-AzureDepthsResourceGroup"
}

function Set-AzureDepthsBudget {
    param(
        [string]$RgName,
        [string]$Name,
        [decimal]$Amount,
        [string]$ContactEmail
    )

    if ([string]::IsNullOrWhiteSpace($ContactEmail)) {
        throw "BudgetContactEmail is required unless -SkipBudget is used."
    }

    $today = Get-Date
    $startDate = Get-Date -Year $today.Year -Month $today.Month -Day 1
    $endDate = $startDate.AddYears(1).AddDays(-1)

    az consumption budget create `
        --resource-group $RgName `
        --budget-name $Name `
        --category cost `
        --amount $Amount `
        --time-grain monthly `
        --start-date ($startDate.ToString("yyyy-MM-dd")) `
        --end-date ($endDate.ToString("yyyy-MM-dd")) `
        --notifications '{"actual_GreaterThan80Percent":{"enabled":true,"operator":"GreaterThan","threshold":80,"contactEmails":["'$ContactEmail'"]},"forecast_GreaterThan100Percent":{"enabled":true,"operator":"GreaterThan","threshold":100,"contactEmails":["'$ContactEmail'"]}}'
    Assert-LastExitCode -StepName "Set-AzureDepthsBudget"
}

function Set-AzureDepthsTagPolicyAssignment {
    param(
        [string]$RgName,
        [string]$DefinitionId
    )

    if ([string]::IsNullOrWhiteSpace($DefinitionId)) {
        throw "PolicyDefinitionId is required unless -SkipPolicy is used."
    }

    $subscriptionIdResolved = az account show --query id -o tsv
    Assert-LastExitCode -StepName "ResolveSubscriptionForPolicyAssignment"

    az policy assignment create `
        --name "azdepths-prod-required-tags" `
        --scope "/subscriptions/$subscriptionIdResolved/resourceGroups/$RgName" `
        --policy $DefinitionId `
        --location $Location
    Assert-LastExitCode -StepName "Set-AzureDepthsTagPolicyAssignment"
}

function Deploy-AzureDepthsStep2 {
    param([string]$RgName)

    az deployment group create `
        --resource-group $RgName `
        --template-file "./infra/main.bicep" `
        --parameters "./infra/prod.bicepparam"
    Assert-LastExitCode -StepName "Deploy-AzureDepthsStep2"
}

function Invoke-Step1And2 {
    Assert-AzCli
    Set-SubscriptionContext -SubId $SubscriptionId
    New-AzureDepthsResourceGroup -RgName $ResourceGroupName -RgLocation $Location

    if (-not $SkipBudget) {
        Set-AzureDepthsBudget -RgName $ResourceGroupName -Name $BudgetName -Amount $BudgetAmountUsd -ContactEmail $BudgetContactEmail
    }

    if (-not $SkipPolicy) {
        Set-AzureDepthsTagPolicyAssignment -RgName $ResourceGroupName -DefinitionId $PolicyDefinitionId
    }

    Deploy-AzureDepthsStep2 -RgName $ResourceGroupName
}

Invoke-Step1And2
