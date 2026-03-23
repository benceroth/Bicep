param namespaceName string

param environmentName string
param projectName string

param vnetName string
param peSubnetName string
param logWorkspaceName string

@allowed(['Basic', 'Standard', 'Premium'])
@description('Service Bus SKU. Premium required for private endpoints and advanced features.')
param skuName string = 'Premium'

@description('Messaging units for Premium SKU. Valid values: 1, 2, 4, 8, 16.')
param capacity int = 1

@description('Enable zone redundancy for the namespace.')
param zoneRedundant bool = true

@description('Optional list of queue names to create.')
param queueNames array = []

// ── Existing resources ──
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logWorkspaceName
}

// ── Service Bus Namespace ──
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: namespaceName
  location: resourceGroup().location
  sku: {
    name: skuName
    tier: skuName
    capacity: skuName == 'Premium' ? capacity : null
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    zoneRedundant: skuName == 'Premium' ? zoneRedundant : false
    premiumMessagingPartitions: skuName == 'Premium' ? 1 : 0
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── Queues ──
resource queues 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = [
  for queueName in queueNames: {
    parent: serviceBusNamespace
    name: queueName
    properties: {
      requiresSession: false
      deadLetteringOnMessageExpiration: true
      maxDeliveryCount: 10
      defaultMessageTimeToLive: 'P14D'
      lockDuration: 'PT1M'
    }
  }
]

// ── Network rule set (deny all public) ──
resource networkRuleSet 'Microsoft.ServiceBus/namespaces/networkRuleSets@2024-01-01' = if (skuName == 'Premium') {
  parent: serviceBusNamespace
  name: 'default'
  properties: {
    defaultAction: 'Deny'
    publicNetworkAccess: 'Disabled'
    trustedServiceAccessEnabled: true
  }
}

// ── Private Endpoint ──
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = if (skuName == 'Premium') {
  name: 'pe-${namespaceName}'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetName, peSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${namespaceName}'
        properties: {
          privateLinkServiceId: serviceBusNamespace.id
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── Private DNS Zone ──
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (skuName == 'Premium') {
  name: 'privatelink.servicebus.windows.net'
  location: 'global'
  properties: {}
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (skuName == 'Premium') {
  parent: privateDnsZone
  name: 'pdz-${namespaceName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resourceId('Microsoft.Network/VirtualNetworks', vnetName)
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = if (skuName == 'Premium') {
  parent: privateEndpoint
  name: 'pdzg-${namespaceName}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ── Diagnostics ──
resource diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: serviceBusNamespace
  name: namespaceName
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output serviceBusNamespaceId string = serviceBusNamespace.id
output serviceBusNamespaceName string = serviceBusNamespace.name
