param functionAppName string
param serviceBusNamespaceName string

var serviceBusReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'

resource functionApp 'Microsoft.Web/sites@2024-04-01' existing = {
  name: functionAppName
}

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
