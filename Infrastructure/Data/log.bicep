param environmentName string
param projectName string

param logWorkspaceName string
param logCapacityPerDay int


resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logWorkspaceName
  location: resourceGroup().location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name:'PerGB2018'
    }
    workspaceCapping: {
      dailyQuotaGb: logCapacityPerDay
    }
  })
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

output logWorkspaceId string = logAnalytics.id
output logWorkspaceName string = logAnalytics.name
