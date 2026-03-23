// Unified Function App module
// Supports: SystemAssigned (default) or UserAssigned identity
// Supports: dotnet-isolated, powershell, node, python, java runtimes

param environmentName string
param projectName string
param vnetName string
param faSubnetName string

param appName string
param functionAppRuntime string
param functionAppRuntimeVersion string

param keyVaultName string
param logWorkspaceName string
param storageAccountName string

@description('Custom app settings merged into the function app configuration.')
param appSettings object = {}

@allowed(['SystemAssigned', 'UserAssigned'])
@description('Identity type for the function app. Use UserAssigned for cross-tenant or shared identity scenarios.')
param identityType string = 'SystemAssigned'

@description('Cosmos DB account name for SQL role assignment. Leave empty to skip.')
param cosmosAccountName string = ''

@description('Service Bus namespace name for Data Receiver role assignment. Leave empty to skip.')
param serviceBusNamespaceName string = ''

@description('App Service Plan SKU name. Default S1.')
param aspSkuName string = 'S1'

@description('App Service Plan SKU tier. Default Standard.')
param aspSkuTier string = 'Standard'

var functionAppName = 'fa-${appName}'
var appinsightsName = 'appi-${appName}'
var isSystemAssigned = identityType == 'SystemAssigned'
var isPowerShell = functionAppRuntime == 'powershell'

// Well-known role definition IDs
var keyVaultReaderRoleId = '21090545-7ca7-4776-b22c-e363652d74d2'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var monitoringMetricsPublisherId = '3913510d-42f4-4e42-8a64-420c390055eb'
var serviceBusDataReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'

// ── Existing resources ──
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource vault 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = {
  name: keyVaultName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

// ── User Assigned Identity (created only when identityType == 'UserAssigned') ──
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (!isSystemAssigned) {
  name: 'uai-data-owner-${appName}'
  location: resourceGroup().location
}

// ── Application Insights ──
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appinsightsName
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
    DisableLocalAuth: true
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── App Service Plan ──
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'asp-${appName}'
  location: resourceGroup().location
  sku: {
    tier: aspSkuTier
    name: aspSkuName
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── Shared app settings (common to all identity types) ──
var baseAppSettings = {
  APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
  APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
  ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
  InstrumentationEngine_EXTENSION_VERSION: 'disabled'
  XDT_MicrosoftApplicationInsights_BaseExtension: 'disabled'
  XDT_MicrosoftApplicationInsights_Mode: 'recommended'
  AzureWebJobsStorage__accountName: storageAccount.name
  AzureWebJobsStorage__credential: 'managedidentity'
  FUNCTIONS_EXTENSION_VERSION: '~4'
  FUNCTIONS_WORKER_RUNTIME: functionAppRuntime
  FUNCTIONS_WORKER_RUNTIME_VERSION: functionAppRuntimeVersion
  WEBSITE_RUN_FROM_PACKAGE: '1'
}

var systemAssignedSettings = {
  APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD'
}

var userAssignedSettings = {
  APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD;ClientId=${isSystemAssigned ? '' : userAssignedIdentity.properties.clientId}'
  AzureWebJobsStorage__clientId: isSystemAssigned ? '' : userAssignedIdentity.properties.clientId
}

var identitySpecificSettings = isSystemAssigned ? systemAssignedSettings : userAssignedSettings
var mergedAppSettings = union(baseAppSettings, identitySpecificSettings, appSettings)

// ── Function App ──
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: resourceGroup().location
  kind: 'functionapp,windows'
  identity: isSystemAssigned
    ? { type: 'SystemAssigned' }
    : {
        type: 'UserAssigned'
        userAssignedIdentities: {
          '${userAssignedIdentity.id}': {}
        }
      }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetName, faSubnetName)
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.3'
      netFrameworkVersion: isPowerShell ? null : functionAppRuntimeVersion
      powerShellVersion: isPowerShell ? functionAppRuntimeVersion : null
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: true
      vnetRouteAllEnabled: false
      use32BitWorkerProcess: false
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictions: [
        {
          ipAddress: 'AzureCloud'
          action: 'Allow'
          tag: 'ServiceTag'
          priority: 100
          name: 'DevOps'
        }
        {
          ipAddress: 'Any'
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsUseMain: false
    }
    clientCertEnabled: true
    clientCertMode: 'Optional'
  }
  resource functionAppConfig 'config' = {
    name: 'appsettings'
    properties: mergedAppSettings
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── Principal ID used for RBAC ──
var principalId = isSystemAssigned
  ? functionApp.identity.principalId
  : userAssignedIdentity.properties.principalId

// ── RBAC: Storage Blob Data Contributor ──
resource roleAssignmentBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storageAccount.id, functionApp.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// ── RBAC: Monitoring Metrics Publisher ──
resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, functionApp.id, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
  }
}

// ── RBAC: Key Vault Secrets User ──
resource roleAssignmentKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, functionApp.id, 'Key Vault Secrets User')
  scope: vault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

// ── RBAC: Key Vault Reader ──
resource roleAssignmentKeyVaultReaderUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, functionApp.id, 'Key Vault Reader')
  scope: vault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultReaderRoleId)
  }
}

// ── Cosmos DB SQL Role Assignment (Contributor) ──
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = if (cosmosAccountName != '') {
  name: cosmosAccountName
}

resource cosmosRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-12-01-preview' = if (cosmosAccountName != '') {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, functionApp.id, 'Cosmos DB Contributor')
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    principalId: principalId
    scope: cosmosAccount.id
  }
}

// ── RBAC: Service Bus Data Receiver ──
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = if (serviceBusNamespaceName != '') {
  name: serviceBusNamespaceName
}

resource roleAssignmentServiceBusReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (serviceBusNamespaceName != '') {
  name: guid(subscription().id, serviceBusNamespace.id, functionApp.id, 'Service Bus Data Receiver')
  scope: serviceBusNamespace
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataReceiverRoleId)
  }
}

// ── Diagnostics ──
resource diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: functionAppName
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

output appinsightsName string = appinsightsName
output functionAppName string = functionAppName
output functionAppPrincipalId string = principalId
