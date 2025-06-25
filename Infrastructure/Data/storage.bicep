param storageAccountName string

param environmentName string
param projectName string

param vnetName string
param peSubnetName string
param logWorkspaceName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowedCopyScope: 'PrivateLink'
    allowSharedKeyAccess: false
    encryption: {
      requireInfrastructureEncryption: true
    }
    isHnsEnabled: true
    isLocalUserEnabled: false
    isNfsV3Enabled: false
    isSftpEnabled: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource storageAccountPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${storageAccountName}'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetName, peSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${storageAccountName}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
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

resource storageAccountPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  properties: {}
  dependsOn: [
    virtualNetwork
  ]
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource storageAccountPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageAccountPrivateDnsZone
  name: 'pdz-${storageAccountName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: storageAccountPrivateEndpoint
  name: 'pdzg-${storageAccountName}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: storageAccountPrivateDnsZone.id
        }
      }
    ]
  }
}

resource diagnosticsStorage 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: storageAccountName
  properties: {
    workspaceId: logWorkspace.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource diagnosticsBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: storageAccountName
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource diagnosticsFile 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: fileService
  name: storageAccountName
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource diagnosticsQueue 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: queueService
  name: storageAccountName
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource diagnosticsTable 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: tableService
  name: storageAccountName
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}
