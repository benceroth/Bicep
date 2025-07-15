param cosmosName string
param functionAppName string
param serviceBusNamespaceName string

resource functionApp 'Microsoft.Web/sites@2024-04-01' existing = {
  name: functionAppName
}

var serviceBusReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
resource serviceBusNamespace 'Microsoft.Relay/namespaces@2024-01-01' existing = {
  name: serviceBusNamespaceName
}

resource roleAssignmentServiceBusReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, serviceBusNamespace.id, functionApp.id, 'Service Bus Receiver')
  scope: serviceBusNamespace
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusReceiverRoleId)
  }
}

var cosmosContributorId = '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosName}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-05-01-preview' existing = {
  name: cosmosName
}

resource roleAssignmentCosmosContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-05-01-preview' = {
  parent: cosmosAccount
  name: guid(subscription().id, cosmosAccount.id, functionApp.id, 'Cosmos Db Contributor role')
  properties: {
    roleDefinitionId: cosmosContributorId
    principalId: functionApp.identity.principalId
    scope: cosmosAccount.id
  }
}
