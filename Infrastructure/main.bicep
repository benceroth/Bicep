param environmentName string
param projectName string

param vnetName string
param nsgName string
param faSubnetName string
param peSubnetName string
param webSubnetName string
param amplsSubnetName string

param cosmosName string
param cosmosContainerName string
param cosmosThroughputLimit int
param cosmosUseFreeTier bool

param actionGroupName string
param actionGroupShortName string
param actionGroupEmailAddress string

param keyVaultName string
param logWorkspaceName string

param storageAccountName string

param functionAppSettings object

param authClientId string
@secure()
param authClientSecret string


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

module logModule 'Data/log.bicep' = {
  name: 'log'
  params: {
    environmentName: environmentName
    projectName: projectName
    logWorkspaceName: logWorkspaceName
    logCapacityPerDay: 1
  }
}

module storageModule 'Data/storage.bicep' = {
  name: 'storage'
  params: {
    environmentName: environmentName
    projectName: projectName
    vnetName: vnetName
    peSubnetName: peSubnetName
    storageAccountName: storageAccountName
    logWorkspaceName: logWorkspaceName
  }
  dependsOn: [networkModule, logModule]
}

module vaultModule 'Data/keyvault.bicep' = {
  name: 'vault'
  params: {
    environmentName: environmentName
    projectName: projectName
    vnetName: vnetName
    peSubnetName: peSubnetName
    keyVaultName: keyVaultName
    logWorkspaceName: logWorkspaceName
  }
  dependsOn: [networkModule, logModule]
}

module vaultSecretModule 'Data/keyvault-secret.bicep' = {
  params: {
    keyVaultName: keyVaultName
    secretNames: ['cosmosdb-account', 'cosmosdb-database']
    secretValues: [cosmosName, projectName]
  }
  dependsOn: [vaultModule]
}

module cosmosModule 'Data/cosmosdb.bicep' = {
  params: {
    accountName: cosmosName
    containerName: cosmosContainerName
    containerThroughput: cosmosThroughputLimit
    databaseName: projectName
    environmentName: environmentName
    peSubnetName: peSubnetName
    projectName: projectName
    useFreeTier: cosmosUseFreeTier
    vnetName: vnetName
    logWorkspaceName: logWorkspaceName
  }
  dependsOn: [networkModule, logModule]
}

module netfaModule 'Apps/dotnet-functionapp-mi.bicep' = {
  name: 'netfa'
  params: {
    environmentName: environmentName
    projectName: projectName
    vnetName: vnetName
    keyVaultName: keyVaultName
    faSubnetName: faSubnetName
    appName: projectName
    functionAppRuntime: 'dotnet-isolated'
    functionAppRuntimeVersion: '8.0'
    logWorkspaceName: logWorkspaceName
    storageAccountName: storageAccountName
    appSettings: functionAppSettings
  }
  dependsOn: [networkModule, storageModule, logModule]
}

module netappModule 'Apps/dotnet-appservice-portal.bicep' = {
  params: {
    appName: projectName
    appRuntimeVersion: 'v8.0'
    environmentName: environmentName
    keyVaultName: keyVaultName
    logWorkspaceName: logWorkspaceName
    projectName: projectName
    vnetName: vnetName
    webSubnetName: webSubnetName
    authClientId: authClientId
    authClientSecret: authClientSecret
  }
  dependsOn: [networkModule, storageModule, logModule, vaultModule]
}

module actionGroup 'Alerts/actiongroup.bicep' = {
  params: {
    actionGroupEmailAddress: actionGroupEmailAddress
    actionGroupName: actionGroupName
    actionGroupShortName: actionGroupShortName
    environmentName: environmentName
    projectName: projectName
  }
}

module logalertNetFaModule 'Alerts/logalert-appinsights.bicep' = {
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
  dependsOn: [actionGroup]
}

module logalertAppFaModule 'Alerts/logalert-appinsights.bicep' = {
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
  dependsOn: [actionGroup]
}
