// Unified App Service module
// Supports: optional Front Door integration, optional Entra ID authentication

param environmentName string
param projectName string
param vnetName string
param webSubnetName string

param appName string
param appRuntimeVersion string

param keyVaultName string
param logWorkspaceName string

@description('Entra ID app registration client ID. Leave empty to skip auth configuration.')
param authClientId string = ''

@secure()
@description('Entra ID app registration client secret. Leave empty to skip auth configuration.')
param authClientSecret string = ''

@description('Front Door profile ID (GUID). Leave empty to skip Front Door IP restrictions.')
param frontDoorId string = ''

@description('Front Door endpoint URL (https://...). Leave empty to skip Front Door auth redirect.')
param frontDoorUrl string = ''

@description('App Service Plan SKU name. Default S1.')
param aspSkuName string = 'S1'

@description('App Service Plan SKU tier. Default Standard.')
param aspSkuTier string = 'Standard'

var appServiceName = 'app-${appName}'
var appinsightsName = 'appi-${appName}'
var useFrontDoor = !empty(frontDoorId) && !empty(frontDoorUrl)
var useAuth = !empty(authClientId) && !empty(authClientSecret)

// Well-known role definition IDs
var keyVaultReaderRoleId = '21090545-7ca7-4776-b22c-e363652d74d2'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var monitoringMetricsPublisherId = '3913510d-42f4-4e42-8a64-420c390055eb'

// ── Existing resources ──
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource vault 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = {
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

// ── IP Security Restrictions ──
var frontDoorIpRestrictions = [
  {
    priority: 100
    name: 'FrontDoor'
    tag: 'ServiceTag'
    ipAddress: 'AzureFrontDoor.Backend'
    headers: {
      'x-azure-fdid': [frontDoorId]
    }
    action: 'Allow'
  }
  {
    ipAddress: 'Any'
    action: 'Deny'
    priority: 2147483647
    name: 'Deny all'
    description: 'Deny all access'
  }
]

var defaultIpRestrictions = [
  {
    ipAddress: 'Any'
    action: 'Deny'
    priority: 2147483647
    name: 'Deny all'
    description: 'Deny all access'
  }
]

// ── App Service ──
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
      minTlsVersion: '1.3'
      netFrameworkVersion: appRuntimeVersion
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: true
      vnetRouteAllEnabled: false
      use32BitWorkerProcess: false
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictions: useFrontDoor ? frontDoorIpRestrictions : defaultIpRestrictions
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
    properties: {
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      InstrumentationEngine_EXTENSION_VERSION: 'disabled'
      XDT_MicrosoftApplicationInsights_BaseExtension: 'disabled'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      WEBSITE_RUN_FROM_PACKAGE: '1'
      ENTRAID_AUTH_AAD_SECRET: authClientSecret // for EntraId Easy auth
      WEBSITE_AUTH_AAD_ALLOWED_TENANTS: tenant().tenantId // for multi-tenant applications leverage param here
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── Auth settings (single resource, conditionally includes Front Door properties) ──
resource authSettings 'Microsoft.Web/sites/config@2024-11-01' = if (useAuth) {
  parent: appService
  name: 'authsettingsV2'
  properties: union(
    {
      globalValidation: {
        requireAuthentication: true
        unauthenticatedClientAction: 'RedirectToLoginPage' // for APIs switch to 'Return401'
      }
      platform: {
        enabled: true
        runtimeVersion: '2'
      }
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            clientId: authClientId
            clientSecretSettingName: 'ENTRAID_AUTH_AAD_SECRET'
            openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/v2.0' // for multi-tenant applications leverage param here
          }
          validation: useFrontDoor
            ? {
                allowedAudiences: [frontDoorUrl]
              }
            : {}
        }
      }
    },
    useFrontDoor
      ? {
          httpSettings: {
            requireHttps: true
            forwardProxy: {
              convention: 'Standard'
            }
          }
          login: {
            allowedExternalRedirectUrls: [
              '${frontDoorUrl}/.auth/login/aad/callback'
            ]
          }
        }
      : {}
  )
}

// ── RBAC: Key Vault Secrets User ──
resource roleAssignmentKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, appService.id, 'Key Vault Secrets User')
  scope: vault
  properties: {
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

// ── RBAC: Key Vault Reader ──
resource roleAssignmentKeyVaultReaderUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, vault.id, appService.id, 'Key Vault Reader')
  scope: vault
  properties: {
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultReaderRoleId)
  }
}

// ── RBAC: Monitoring Metrics Publisher ──
resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, appService.id, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Diagnostics ──
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
output appServiceHostName string = appService.properties.defaultHostName
