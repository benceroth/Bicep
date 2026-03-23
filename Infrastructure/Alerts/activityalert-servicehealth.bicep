param alertRuleName string
param actionGroupName string

param environmentName string
param projectName string

resource alertRule 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: alertRuleName
  location: 'global'
  properties: {
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ResourceHealth'
        }
        {
          anyOf: [
            {
              field: 'resourceGroup'
              equals: resourceGroup().name
            }
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: resourceId('Microsoft.Insights/actionGroups', actionGroupName)
          webhookProperties: {}
        }
      ]
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}
