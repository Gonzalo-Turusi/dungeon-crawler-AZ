targetScope = 'resourceGroup'

param org string
param app string
param env string
param namePrefix string
param coreRegion string
@description('Region for Static Web Apps only (e.g. eastus2); not all regions support Microsoft.Web/staticSites.')
param aiRegion string
param sequence string
param tags object

var modulePrefix = '${org}-${app}-${env}'
var functionAppName = '${modulePrefix}-func-${sequence}'
var apimName = '${modulePrefix}-apim-${sequence}'
var staticWebAppName = '${modulePrefix}-swa-${sequence}'
var functionStorageName = toLower('${take(replace('${modulePrefix}${namePrefix}', '-', ''), 17)}fnst${sequence}')
var functionPlanName = '${modulePrefix}-asp-${sequence}'

resource functionStorage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: functionStorageName
  location: coreRegion
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource functionPlan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: functionPlanName
  location: coreRegion
  tags: tags
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2025-03-01' = {
  name: functionAppName
  location: coreRegion
  tags: tags
  kind: 'functionapp'
  properties: {
    serverFarmId: functionPlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};AccountKey=${functionStorage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
      ]
    }
  }
}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: coreRegion
  tags: tags
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'your-publisher-email@example.com'
    publisherName: 'Platform Team'
  }
}

resource staticWebApp 'Microsoft.Web/staticSites@2025-03-01' = {
  name: staticWebAppName
  location: aiRegion
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

output resourceNames object = {
  coreRegion: coreRegion
  functionStorage: functionStorageName
  functionPlan: functionPlanName
  functionAppId: functionApp.id
  functionApp: functionAppName
  apimId: apim.id
  apim: apimName
  apimSku: 'Consumption'
  staticWebAppId: staticWebApp.id
  staticWebApp: staticWebAppName
  staticWebAppSku: 'Free'
  hasHardcodedConnectionStrings: false
  tagsApplied: tags
}
