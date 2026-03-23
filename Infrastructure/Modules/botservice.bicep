// Bot Service module
// Deploys Azure Bot resource with user-assigned managed identity,
// Teams channel, optional OAuth SSO connection, and diagnostic settings

param environmentName string
param projectName string

param botServiceName string
param botDisplayName string

@description('Hostname of the dedicated bot host App Service (e.g. app-mybot.azurewebsites.net).')
param botEndpointHostName string

param logWorkspaceName string

@description('Resource ID of the shared user-assigned managed identity.')
param userAssignedIdentityId string

@description('Client ID of the Entra ID app registration used as msaAppId.')
param msaAppId string

@allowed(['F0', 'S1'])
@description('Bot Service SKU. F0 for free, S1 for standard.')
param skuName string = 'S1'

@description('Enable the Microsoft Teams channel.')
param enableTeamsChannel bool = true

@description('Enable an OAuth SSO connection for Entra ID / Microsoft Graph.')
param enableSsoConnection bool = false

@description('Display name for the SSO connection.')
param ssoConnectionName string = 'EntraIdConnection'

@description('Entra ID app registration client ID for the SSO connection.')
param ssoClientId string = ''

@secure()
@description('Entra ID app registration client secret for the SSO connection.')
param ssoClientSecret string = ''

@description('OAuth scopes for the SSO connection (space-separated).')
param ssoScopes string = 'openid profile User.Read'

@description('Application Insights instrumentation key for bot telemetry.')
param appInsightsKey string = ''

@description('Application Insights app ID for bot telemetry.')
param appInsightsAppId string = ''

// Well-known Entra ID / Azure AD Bot Framework OAuth service provider ID
var entraIdServiceProviderId = '30dd229c-58e3-4a48-bdfd-91ec48eb906c'

// ── Existing resources ──
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

// ── Bot Service ──
resource botService 'Microsoft.BotService/botServices@2023-09-15-preview' = {
  name: botServiceName
  location: 'global'
  kind: 'azurebot'
  sku: {
    name: skuName
  }
  properties: {
    displayName: botDisplayName
    endpoint: 'https://${botEndpointHostName}/api/messages'
    msaAppId: msaAppId
    msaAppType: 'UserAssignedMSI'
    msaAppMSIResourceId: userAssignedIdentityId
    #disable-next-line use-resource-id-functions
    msaAppTenantId: tenant().tenantId
    disableLocalAuth: true
    isStreamingSupported: true
    developerAppInsightKey: !empty(appInsightsKey) ? appInsightsKey : ''
    developerAppInsightsApplicationId: !empty(appInsightsAppId) ? appInsightsAppId : ''
    publicNetworkAccess: 'Enabled'
    schemaTransformationVersion: '1.3'
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

// ── Teams Channel ──
resource teamsChannel 'Microsoft.BotService/botServices/channels@2023-09-15-preview' = if (enableTeamsChannel) {
  parent: botService
  name: 'MsTeamsChannel'
  location: 'global'
  properties: {
    channelName: 'MsTeamsChannel'
    properties: {
      isEnabled: true
      acceptedTerms: true
      enableCalling: false
    }
  }
}

// ── OAuth SSO Connection (Entra ID / Microsoft Graph) ──
resource ssoConnection 'Microsoft.BotService/botServices/connections@2023-09-15-preview' = if (enableSsoConnection && !empty(ssoClientId)) {
  parent: botService
  name: ssoConnectionName
  location: 'global'
  properties: {
    clientId: ssoClientId
    clientSecret: ssoClientSecret
    scopes: ssoScopes
    serviceProviderId: entraIdServiceProviderId
    serviceProviderDisplayName: 'Azure Active Directory v2'
    parameters: [
      {
        key: 'tenantID'
        value: tenant().tenantId
      }
      {
        key: 'tokenExchangeUrl'
        value: 'api://${msaAppId}'
      }
    ]
  }
}

// ── Diagnostic Settings ──
resource diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: botService
  name: botServiceName
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

output botServiceId string = botService.id
output botServiceName string = botService.name
output botMessagingEndpoint string = botService.properties.endpoint
