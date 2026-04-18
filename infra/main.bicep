targetScope = 'resourceGroup'

@description('Organization short code used in resource naming.')
param org string

@description('Application short code used in resource naming.')
param app string = 'azdepths'

@description('Environment short code used in resource naming.')
@allowed([
  'dev'
  'qa'
  'prod'
])
param env string = 'prod'

@description('Core region where most resources are deployed.')
param coreRegion string = resourceGroup().location

@description('AI region for Azure OpenAI fallback if needed.')
param aiRegion string = 'eastus2'

@description('Instance sequence number.')
@minValue(1)
param instance int = 1

@description('Standard tags applied to every resource.')
param tags object

@description('SQL Server administrator login.')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server administrator password.')
@secure()
param sqlAdminPassword string

var regionShortMap = {
  brazilsouth: 'brs'
  eastus2: 'eus2'
}

var coreRegionShort = regionShortMap[?toLower(coreRegion)] ?? toLower(replace(coreRegion, ' ', ''))
var aiRegionShort = regionShortMap[?toLower(aiRegion)] ?? toLower(replace(aiRegion, ' ', ''))
var sequence = padLeft(string(instance), 2, '0')
var namePrefix = '${org}-${app}-${env}-${coreRegionShort}'

module identitySecurity './modules/identity-security.bicep' = {
  name: 'identity-security'
  params: {
    org: org
    app: app
    env: env
    namePrefix: namePrefix
    coreRegion: coreRegion
    aiRegion: aiRegion
    aiRegionShort: aiRegionShort
    sequence: sequence
    tags: tags
  }
}

module data './modules/data.bicep' = {
  name: 'data'
  params: {
    org: org
    app: app
    env: env
    namePrefix: namePrefix
    coreRegion: coreRegion
    sequence: sequence
    tags: tags
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
  }
}

module messaging './modules/messaging.bicep' = {
  name: 'messaging'
  params: {
    org: org
    app: app
    env: env
    coreRegion: coreRegion
    sequence: sequence
    tags: tags
  }
}

module computeEdge './modules/compute-edge.bicep' = {
  name: 'compute-edge'
  params: {
    org: org
    app: app
    env: env
    namePrefix: namePrefix
    coreRegion: coreRegion
    aiRegion: aiRegion
    sequence: sequence
    tags: tags
  }
}

output namingConvention string = '{org}-{app}-{env}-{region}-{service}-{nn}'
output coreNamePrefix string = namePrefix
output coreRegionOutput string = coreRegion
output aiRegionOutput string = aiRegion
output modules object = {
  identitySecurity: identitySecurity.outputs.resourceNames
  data: data.outputs.resourceNames
  messaging: messaging.outputs.resourceNames
  computeEdge: computeEdge.outputs.resourceNames
}
