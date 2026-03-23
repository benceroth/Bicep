// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  main.bicep — Modular orchestrator with feature flags                  ║
// ║  Enable/disable components per use-case via boolean parameters.        ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// ── Core parameters ──
param environmentName string
param projectName string

// ── Feature flags — toggle components per use-case ──
@description('Deploy Cosmos DB resources.')
param enableCosmos bool = true

@description('Deploy a .NET Function App (via unified Modules/functionapp.bicep).')
param enableFunctionApp bool = true

@description('Deploy a .NET App Service (via unified Modules/appservice.bicep).')
param enableAppService bool = true

@description('Deploy Azure Front Door and WAF policy.')
param enableFrontDoor bool = true

@description('Deploy alert rules and action groups.')
param enableAlerts bool = true

@description('Deploy Azure Service Bus namespace.')
param enableServiceBus bool = false

// ── Cosmos parameters ──
param cosmosContainerName string = ''
param cosmosThroughputLimit int = 1000
param cosmosUseFreeTier bool = true

// ── Alert parameters ──
param actionGroupShortName string = ''
param actionGroupEmailAddress string = ''

// ── Front Door / custom domain ──
param customDomainHost string = ''

// ── App Service auth ──
param authClientId string = ''
@secure()
param authClientSecret string = ''

// ── Log Analytics ──
@description('Daily ingestion cap in GB for Log Analytics.')
param logCapacityPerDay int = 1

// ── Service Bus ──
@allowed(['Basic', 'Standard', 'Premium'])
@description('Service Bus SKU. Premium required for private endpoints.')
param serviceBusSku string = 'Premium'

@description('Optional list of Service Bus queue names to create.')
param serviceBusQueues array = []

// ── Function App settings ──
@description('Identity type for the function app. SystemAssigned or UserAssigned.')
@allowed(['SystemAssigned', 'UserAssigned'])
param functionAppIdentityType string = 'SystemAssigned'

param functionAppRuntime string = 'dotnet-isolated'
param functionAppRuntimeVersion string = '8.0'

param appServiceRuntimeVersion string = 'v8.0'

// ── Naming conventions ──
var actionGroupName = 'ag-${projectName}'
var keyVaultName = 'kv-${projectName}'
var logWorkspaceName = 'law-${projectName}'
var storageAccountName = 'st${projectName}'
var frontDoorName = 'afd-${projectName}'
var wafPolicyName = 'waf${projectName}'
var vnetName = 'vnet-${projectName}'
var nsgName = 'nsg-${projectName}'
var faSubnetName = 'snet-fas'
var peSubnetName = 'snet-pes'
var webSubnetName = 'snet-web'
var amplsSubnetName = 'snet-ampls'
var cosmosName = 'cosmos-${projectName}'
var serviceBusName = 'sb-${projectName}'

// Sample application environment settings (used when enableFunctionApp == true)
var functionAppSettings = enableFunctionApp ? {
  'KeyVaultConfig:Name': keyVaultName
  'AzureWebJobs.FunctionName.Schedule': '0 */5 * * * *'
  'Config:CosmosContainer': cosmosContainerName
  'Config:MetricsTimeRangeInMinutes': 5
  'Config:MetricTypeMaxCount': 5
  'Config:Subscriptions': null
  'Config:ResourceGroups': null
} : {}

// ═══════════════════════════════════════════════════════════════════════════
// Network
// ═══════════════════════════════════════════════════════════════════════════
module networkModule 'network.bicep' = {
  name: 'network'
  params: {
    environmentName: environmentName
    projectName: projectName
    vnetName: vnetName
    nsgName: nsgName
    faSubnetName: faSubnetName
    webSubnetName: webSubnetName
    amplsSubnetName: amplsSubnetName
    peSubnetName: peSubnetName
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data — Log Analytics
// ═══════════════════════════════════════════════════════════════════════════
module logModule 'Data/log.bicep' = {
  name: 'log'
  params: {
    environmentName: environmentName
    projectName: projectName
    logWorkspaceName: logWorkspaceName
    logCapacityPerDay: logCapacityPerDay
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data — Storage
// ═══════════════════════════════════════════════════════════════════════════
module storageModule 'Data/storage.bicep' = {
  name: 'storage'
  params: {
    environmentName: environmentName
    projectName: projectName
    vnetName: networkModule.outputs.vnetName
    peSubnetName: peSubnetName
    storageAccountName: storageAccountName
    logWorkspaceName: logModule.outputs.logWorkspaceName
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data — Key Vault
// ═══════════════════════════════════════════════════════════════════════════
module vaultModule 'Data/keyvault.bicep' = {
  name: 'vault'
  params: {
    environmentName: environmentName
    projectName: projectName
    vnetName: networkModule.outputs.vnetName
    peSubnetName: peSubnetName
    keyVaultName: keyVaultName
    logWorkspaceName: logModule.outputs.logWorkspaceName
  }
}

module vaultSecretModule 'Data/keyvault-secret.bicep' = {
  name: 'vaultSecrets'
  params: {
    keyVaultName: vaultModule.outputs.keyVaultName
    secretNames: enableCosmos ? ['cosmosdb-account', 'cosmosdb-database'] : []
    secretValues: enableCosmos ? [cosmosName, projectName] : []
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data — Cosmos DB (optional)
// ═══════════════════════════════════════════════════════════════════════════
module cosmosModule 'Data/cosmosdb.bicep' = if (enableCosmos) {
  name: 'cosmos'
  params: {
    accountName: cosmosName
    containerName: cosmosContainerName
    containerThroughput: cosmosThroughputLimit
    databaseName: projectName
    environmentName: environmentName
    peSubnetName: peSubnetName
    projectName: projectName
    useFreeTier: cosmosUseFreeTier
    vnetName: networkModule.outputs.vnetName
    logWorkspaceName: logModule.outputs.logWorkspaceName
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data — Service Bus (optional)
// ═══════════════════════════════════════════════════════════════════════════
module serviceBusModule 'Data/servicebus.bicep' = if (enableServiceBus) {
  name: 'servicebus'
  params: {
    namespaceName: serviceBusName
    environmentName: environmentName
    projectName: projectName
    vnetName: networkModule.outputs.vnetName
    peSubnetName: peSubnetName
    logWorkspaceName: logModule.outputs.logWorkspaceName
    skuName: serviceBusSku
    queueNames: serviceBusQueues
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Apps — Function App (optional, unified module)
// ═══════════════════════════════════════════════════════════════════════════
module netfaModule 'Modules/functionapp.bicep' = if (enableFunctionApp) {
  name: 'netfa'
  params: {
    environmentName: environmentName
    projectName: projectName
    vnetName: networkModule.outputs.vnetName
    keyVaultName: vaultModule.outputs.keyVaultName
    faSubnetName: faSubnetName
    appName: projectName
    functionAppRuntime: functionAppRuntime
    functionAppRuntimeVersion: functionAppRuntimeVersion
    logWorkspaceName: logModule.outputs.logWorkspaceName
    storageAccountName: storageModule.outputs.storageAccountName
    appSettings: functionAppSettings
    identityType: functionAppIdentityType
    cosmosAccountName: enableCosmos ? cosmosModule.outputs.cosmosAccountName : ''
    serviceBusNamespaceName: enableServiceBus ? serviceBusModule.outputs.serviceBusNamespaceName : ''
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Security — Front Door (optional)
// ═══════════════════════════════════════════════════════════════════════════
module frontdoorModule './Security/frontdoor.bicep' = if (enableFrontDoor) {
  name: 'frontdoor'
  params: {
    frontDoorName: frontDoorName
    wafPolicyName: wafPolicyName
    environmentName: environmentName
    projectName: projectName
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Apps — App Service (optional, unified module)
// ═══════════════════════════════════════════════════════════════════════════
module netappModule 'Modules/appservice.bicep' = if (enableAppService) {
  name: 'netapp'
  params: {
    appName: projectName
    appRuntimeVersion: appServiceRuntimeVersion
    environmentName: environmentName
    keyVaultName: vaultModule.outputs.keyVaultName
    logWorkspaceName: logModule.outputs.logWorkspaceName
    projectName: projectName
    vnetName: networkModule.outputs.vnetName
    webSubnetName: webSubnetName
    authClientId: authClientId
    authClientSecret: authClientSecret
    frontDoorId: enableFrontDoor ? frontdoorModule.outputs.frontDoorId : ''
    frontDoorUrl: enableFrontDoor ? frontdoorModule.outputs.frontDoorUrl : ''
  }
}

module frontdoorOriginModule './Security/frontdoor-origin.bicep' = if (enableFrontDoor && enableAppService) {
  name: 'frontDoorOrigin'
  params: {
    appHostName: netappModule.outputs.appServiceHostName
    customDomainHost: customDomainHost
    frontDoorName: frontdoorModule.outputs.frontDoorName
    frontDoorEndpointName: frontdoorModule.outputs.frontDoorEndpointName
    environmentName: environmentName
    projectName: projectName
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Alerts (optional)
// ═══════════════════════════════════════════════════════════════════════════
module actionGroup 'Alerts/actiongroup.bicep' = if (enableAlerts) {
  name: 'actionGroup'
  params: {
    actionGroupEmailAddress: actionGroupEmailAddress
    actionGroupName: actionGroupName
    actionGroupShortName: actionGroupShortName
    environmentName: environmentName
    projectName: projectName
  }
}

module logalertNetFaModule 'Alerts/logalert-appinsights.bicep' = if (enableAlerts && enableFunctionApp) {
  name: 'logalertNetFa'
  params: {
    actionGroupName: actionGroupName
    alertRuleName: 'ar-${netfaModule.outputs.functionAppName}-failures'
    alertRuleQuery: '(traces | where severityLevel == 3 or severityLevel == 4 | project timestamp, message, operation_Id) | union (exceptions | project timestamp, outerMessage, operation_Id)'
    alertRuleSeverity: 1
    alertRuleTitle: 'Error occured in ${netfaModule.outputs.functionAppName}'
    appinsightsName: netfaModule.outputs.appinsightsName
    environmentName: environmentName
    projectName: projectName
  }
}

module logalertAppFaModule 'Alerts/logalert-appinsights.bicep' = if (enableAlerts && enableAppService) {
  name: 'logalertApp'
  params: {
    actionGroupName: actionGroupName
    alertRuleName: 'ar-${netappModule.outputs.appServiceName}-failures'
    alertRuleQuery: '(traces | where severityLevel == 3 or severityLevel == 4 | project timestamp, message, operation_Id) | union (exceptions | project timestamp, outerMessage, operation_Id)'
    alertRuleSeverity: 1
    alertRuleTitle: 'Error occured in ${netappModule.outputs.appServiceName}'
    appinsightsName: netappModule.outputs.appinsightsName
    environmentName: environmentName
    projectName: projectName
  }
}

module activityAlertModule 'Alerts/activityalert-servicehealth.bicep' = if (enableAlerts) {
  name: 'activityAlert'
  params: {
    actionGroupName: actionGroupName
    alertRuleName: 'ar-${projectName}-servicehealth'
    environmentName: environmentName
    projectName: projectName
  }
}
