param accountName string
param databaseName string
param containerName string
param containerThroughput int
param useFreeTier bool

param environmentName string
param projectName string

param vnetName string
param peSubnetName string
param logWorkspaceName string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' = {
  name: accountName
  location: resourceGroup().location
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: useFreeTier
    capacityMode: 'Serverless'
    defaultIdentity: 'FirstPartyIdentity'
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: 'BoundedStaleness'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: resourceGroup().location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 1440
        backupRetentionIntervalInHours: 48
        backupStorageRedundancy: 'Zone'
      }
    }
    capacity: {
      totalThroughputLimit: containerThroughput
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-12-01-preview' = {
  parent: cosmos
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-12-01-preview' = {
  parent: cosmosDatabase
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/timestamp'
        ]
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        compositeIndexes: [
          [
            {
              path: '/resourceId'
              order: 'ascending'
            }
            {
              path: '/timestamp'
              order: 'descending'
            }
          ]
        ]
      }
      defaultTtl: 63072000 // 2 years of data retention
    }
  }
}

resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${accountName}'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetName, peSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${accountName}'
        properties: {
          privateLinkServiceId: cosmos.id
          groupIds: [
            'Sql'
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

resource cosmosPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  properties: {}
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource cosmosPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cosmosPrivateDnsZone
  name: 'pdz-${accountName}-link'
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

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: cosmosPrivateEndpoint
  name: 'pdzg-${accountName}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: cosmosPrivateDnsZone.id
        }
      }
    ]
  }
}

resource diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cosmos
  name: accountName
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
