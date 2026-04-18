targetScope = 'resourceGroup'

param org string
param app string
param env string
param coreRegion string
param sequence string
param tags object

var serviceBusName = '${org}-${app}-${env}-sb-${sequence}'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: serviceBusName
  location: coreRegion
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

output resourceNames object = {
  coreRegion: coreRegion
  serviceBusId: serviceBusNamespace.id
  serviceBus: serviceBusName
  serviceBusSku: 'Basic'
  tagsApplied: tags
}
