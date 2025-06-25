using './main.bicep'

param actionGroupShortName = 'Demo AG'
param actionGroupEmailAddress = 'info@broth.hu'

param projectName = 'demoproject'
param environmentName = 'Development'

param vnetName = 'vnet-${projectName}'
param nsgName = 'nsg-${projectName}'
param faSubnetName = 'snet-fas'
param peSubnetName = 'snet-pes'
param webSubnetName = 'snet-web'
param amplsSubnetName = 'snet-ampls'

param cosmosName = 'cosmos-${projectName}'
param cosmosContainerName = 'demo'
param cosmosUseFreeTier = true
param cosmosThroughputLimit = 1000 // Free tier limit

param actionGroupName = 'ag-${projectName}'

param keyVaultName = 'kv-${projectName}'
param logWorkspaceName = 'law-${projectName}'
param storageAccountName = 'st${projectName}'

// Sample application environment settings
param functionAppSettings = {
  'KeyVaultConfig:Name': keyVaultName
  'AzureWebJobs.FunctionName.Schedule': '0 */5 * * * *'
  'Config:CosmosContainer': cosmosContainerName
  'Config:MetricsTimeRangeInMinutes': 5
  'Config:MetricTypeMaxCount': 5
  'Config:Subscriptions': null
  'Config:ResourceGroups': null
}
