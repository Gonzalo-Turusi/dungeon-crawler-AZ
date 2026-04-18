targetScope = 'resourceGroup'

param org string
param app string
param env string
param namePrefix string
param coreRegion string
param aiRegion string
param aiRegionShort string
param sequence string
param tags object

var modulePrefix = '${org}-${app}-${env}'
var keyVaultName = toLower(replace('${take(replace('${modulePrefix}${namePrefix}', '-', ''), 16)}kv${sequence}', '_', ''))
var managedIdentityName = '${modulePrefix}-mi-${sequence}'
var appInsightsName = '${modulePrefix}-appi-${sequence}'
var openAiName = '${modulePrefix}-${aiRegionShort}-aoai-${sequence}'

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: coreRegion
  tags: tags
}

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: keyVaultName
  location: coreRegion
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: coreRegion
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: null
  }
}

resource azureOpenAi 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAiName
  location: aiRegion
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: take(replace(openAiName, '-', ''), 64)
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

output resourceNames object = {
  coreRegion: coreRegion
  aiRegion: aiRegion
  managedIdentityId: userIdentity.id
  managedIdentity: managedIdentityName
  keyVaultId: keyVault.id
  keyVault: keyVaultName
  appInsightsId: appInsights.id
  appInsights: appInsightsName
  azureOpenAiId: azureOpenAi.id
  azureOpenAi: openAiName
  azureOpenAiSku: 'S0'
  azureOpenAiKind: 'OpenAI'
  keyVaultSecretsInTemplate: false
  tagsApplied: tags
}
