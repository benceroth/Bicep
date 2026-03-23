// Dedicated Bot Host App Service module
// Windows App Service for hosting a .NET 10 bot with Agent SDK and custom LLM API
// Uses a shared user-assigned managed identity for both the App Service and Bot Service
// Platform auth enabled with excluded paths for /api/messages and health endpoints

param environmentName string
param projectName string
param vnetName string
param webSubnetName string

param appName string

param keyVaultName string
param logWorkspaceName string

@description('Entra ID app registration client ID for platform auth.')
param authClientId string

@description('App setting name that holds the Entra ID client credential.')
param authCredentialAppSettingName string = 'ENTRAID_AUTH_AAD_SECRET'

@secure()
@description('Entra ID app registration client secret for platform auth.')
param authClientSecret string = ''

@description('App Service Plan SKU name. Default S1.')
param aspSkuName string = 'S1'

@description('App Service Plan SKU tier. Default Standard.')
param aspSkuTier string = 'Standard'

@description('.NET runtime version for the bot host.')
param dotnetVersion string = 'v10.0'

@description('Custom LLM API endpoint URL injected as app setting.')
param llmApiEndpoint string = ''

@description('Key Vault secret name containing the custom LLM API key.')
param llmApiKeySecretName string = ''

@description('Resource ID of the shared user-assigned managed identity.')
param userAssignedIdentityId string

@description('Principal ID of the shared user-assigned managed identity.')
param userAssignedIdentityPrincipalId string

@description('Client ID of the shared user-assigned managed identity.')
param userAssignedIdentityClientId string

var botAppServiceName = 'app-${appName}-bot'
var appinsightsName = 'appi-${appName}-bot'

// Well-known role definition IDs
var keyVaultReaderRoleId = '21090545-7ca7-4776-b22c-e363652d74d2'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var monitoringMetricsPublisherId = '3913510d-42f4-4e42-8a64-420c390055eb'

// ── Existing resources ──
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logWorkspaceName
}

resource vault 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  name: keyVaultName
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
resource appServicePlan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: 'asp-${appName}-bot'
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

// ── Bot host app settings ──
var baseAppSettings = {
  APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
  APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD;ClientId=${userAssignedIdentityClientId}'
  APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
  ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
  InstrumentationEngine_EXTENSION_VERSION: 'disabled'
  XDT_MicrosoftApplicationInsights_BaseExtension: 'disabled'
  XDT_MicrosoftApplicationInsights_Mode: 'recommended'
  WEBSITE_RUN_FROM_PACKAGE: '1'
  MicrosoftAppType: 'UserAssignedMSI'
  MicrosoftAppId: authClientId
  MicrosoftAppTenantId: tenant().tenantId
  MicrosoftAppPassword: ''
  WEBSITE_AUTH_AAD_ALLOWED_TENANTS: tenant().tenantId
}

var authSecretSetting = !empty(authClientSecret) ? {
  '${authCredentialAppSettingName}': authClientSecret
} : {}

var llmSettings = !empty(llmApiEndpoint) ? {
  'LlmApi:Endpoint': llmApiEndpoint
  'LlmApi:KeySecretName': llmApiKeySecretName
  'LlmApi:KeyVaultUri': vault.properties.vaultUri
} : {}

var mergedAppSettings = union(baseAppSettings, authSecretSetting, llmSettings)

// ── IP Security Restrictions ──
// Bot Service requires a public HTTPS endpoint; restrict to Bot Framework ingress + health checks
var ipSecurityRestrictions = [
  {
    priority: 100
    name: 'AzureBotService'
    tag: 'ServiceTag'
    ipAddress: 'AzureBotService' // well-known tag for Azure Bot Service messaging ingress, but it is not enough, AzureCloud is needed to cover health checks and other service traffic
    action: 'Allow'
    description: 'Azure Bot Service messaging ingress'
  }
  {
    priority: 200
    name: 'AzureHealthChecks'
    tag: 'ServiceTag'
    ipAddress: 'AzureCloud'
    action: 'Allow'
    description: 'Azure health check probes'
  }
  {
    ipAddress: 'Any'
    action: 'Deny'
    priority: 2147483647
    name: 'Deny all'
    description: 'Deny all other access'
  }
]

// ── App Service ──
resource botAppService 'Microsoft.Web/sites@2025-03-01' = {
  name: botAppServiceName
  location: resourceGroup().location
  kind: 'app'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
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
      minTlsVersion: '1.3'
      netFrameworkVersion: dotnetVersion
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: true
      vnetRouteAllEnabled: false
      use32BitWorkerProcess: false
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictions: ipSecurityRestrictions
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
  resource appConfig 'config' = {
    name: 'appsettings'
    properties: mergedAppSettings
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── Auth settings with excluded paths for /api/messages and health ──
resource authSettings 'Microsoft.Web/sites/config@2025-03-01' = if (!empty(authClientId)) {
  parent: botAppService
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
      excludedPaths: [
        '/api/messages'
        '/health'
        '/.well-known/health'
      ]
    }
    platform: {
      enabled: true
      runtimeVersion: '2'
    }
    httpSettings: {
      requireHttps: true
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authClientId
          clientSecretSettingName: authCredentialAppSettingName
          openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${authClientId}'
          ]
        }
      }
    }
  }
}

// ── RBAC: Key Vault Secrets User ──
resource roleAssignmentKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, botAppService.id, 'Key Vault Secrets User')
  scope: vault
  properties: {
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

// ── RBAC: Key Vault Reader ──
resource roleAssignmentKeyVaultReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, botAppService.id, 'Key Vault Reader')
  scope: vault
  properties: {
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultReaderRoleId)
  }
}

// ── RBAC: Monitoring Metrics Publisher ──
resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, botAppService.id, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ── Diagnostics ──
resource diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: botAppService
  name: botAppServiceName
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

output botAppServiceName string = botAppServiceName
output botAppServiceHostName string = botAppService.properties.defaultHostName
output appinsightsName string = appinsightsName
output appinsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output appinsightsAppId string = applicationInsights.properties.AppId
