param keyVaultName string

param environmentName string
param projectName string

param vnetName string
param peSubnetName string
param logWorkspaceName string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource vault 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
    accessPolicies: []
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7 
    enableRbacAuthorization: true
    enablePurgeProtection: true
    vaultUri: 'https://${keyVaultName}.vault.azure.net/'
    provisioningState: 'Succeeded'
    publicNetworkAccess: 'Disabled'
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource vaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${keyVaultName}'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetName, peSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${keyVaultName}'
        properties: {
          privateLinkServiceId: vault.id
          groupIds: [
            'vault'
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

resource vaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  properties: {}
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource vaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: vaultPrivateDnsZone
  name: 'pdz-${keyVaultName}-link'
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
  parent: vaultPrivateEndpoint
  name: 'pdzg-${keyVaultName}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: vaultPrivateDnsZone.id
        }
      }
    ]
  }
}

resource diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vault
  name: keyVaultName
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
