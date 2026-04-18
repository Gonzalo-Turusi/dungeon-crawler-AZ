targetScope = 'resourceGroup'

param org string
param app string
param env string
param namePrefix string
param coreRegion string
@minLength(2)
param sequence string
param tags object
param sqlAdminLogin string = 'sqladmin'
@secure()
param sqlAdminPassword string

var sqlServerName = '${namePrefix}-sql-${sequence}'
var storageAccountName = toLower('${take(replace('${namePrefix}data', '-', ''), 18)}st${sequence}')
var redisName = '${namePrefix}-redis-${sequence}'
var sqlDbName = '${org}-${app}-${env}-gamedb-${sequence}'

resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: sqlServerName
  location: coreRegion
  tags: tags
  properties: {
    version: '12.0'
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01' = {
  parent: sqlServer
  name: sqlDbName
  location: coreRegion
  tags: tags
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    autoPauseDelay: 60
    minCapacity: 1
    zoneRedundant: false
    readScale: 'Disabled'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
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

resource redis 'Microsoft.Cache/Redis@2024-11-01' = {
  name: redisName
  location: coreRegion
  tags: tags
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
  }
}

output resourceNames object = {
  coreRegion: coreRegion
  sqlDatabase: sqlDbName
  sqlSku: 'GP_S_Gen5_1'
  sqlAutoPauseDelayMinutes: 60
  sqlServer: sqlServerName
  storageAccountId: storageAccount.id
  storageAccount: storageAccountName
  redisId: redis.id
  redis: redisName
  redisSkuName: 'Basic'
  redisSkuFamily: 'C'
  redisSkuCapacity: 0
  hasHardcodedSecrets: false
  tagsApplied: tags
}

output sqlAdminLogin string = sqlAdminLogin
