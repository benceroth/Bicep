param environmentName string
param projectName string
param vnetName string
param webSubnetName string

param appName string
param appRuntimeVersion string

param keyVaultName string
param logWorkspaceName string

var appServiceName = 'app-${appName}'
var appinsightsName = 'appi-${appName}'
var keyVaultReaderRoleId = '21090545-7ca7-4776-b22c-e363652d74d2'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var monitoringMetricsPublisherId = '3913510d-42f4-4e42-8a64-420c390055eb'

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource vault 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = {
  name: keyVaultName
}

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

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'asp-${appName}'
  location: resourceGroup().location
  sku: {
    tier: 'Standard'
    name: 'S1'
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource appService 'Microsoft.Web/sites@2024-04-01' = {
  name: appServiceName
  location: resourceGroup().location
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetName, webSubnetName)
    httpsOnly: true
    siteConfig: {
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      minTlsVersion: '1.2'
      netFrameworkVersion: appRuntimeVersion
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
    clientCertMode: 'OptionalInteractiveUser'
  }
  resource appConfig 'config' = {
    name: 'appsettings'
    properties: {
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      InstrumentationEngine_EXTENSION_VERSION: 'disabled'
      XDT_MicrosoftApplicationInsights_BaseExtension: 'disabled'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      WEBSITE_RUN_FROM_PACKAGE: '1'
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource roleAssignmentKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, appService.id, 'Key Vault Secrets User')
  scope: vault
  properties: {
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

resource roleAssignmentKeyVaultReaderUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, appService.id, 'Key Vault Reader')
  scope: vault
  properties: {
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultReaderRoleId)
  }
}

resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, appService.id, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appService
  name: appServiceName
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
output appServiceName string = appServiceName
