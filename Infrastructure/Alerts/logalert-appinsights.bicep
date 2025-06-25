param alertRuleName string
param alertRuleTitle string
param alertRuleSeverity int
param alertRuleQuery string

param appinsightsName string
param actionGroupName string

param environmentName string
param projectName string

resource alertRule 'Microsoft.Insights/scheduledQueryRules@2025-01-01-preview' = {
  name: alertRuleName
  location: resourceGroup().location
  kind: 'LogAlert'
  properties: {
    displayName: alertRuleName
    description: alertRuleTitle
    severity: alertRuleSeverity
    enabled: true
    evaluationFrequency: 'PT1H' // Hourly check
    scopes: [
      resourceId('Microsoft.Insights/components', appinsightsName)
    ]
    targetResourceTypes: [
      'Microsoft.Insights/components'
    ]
    windowSize: 'PT1H' // Last hour as evaluation window
    criteria: {
      allOf: [
        {
          query: alertRuleQuery
          timeAggregation: 'Count'
          dimensions: []
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        resourceId('Microsoft.Insights/actionGroups', actionGroupName)
      ]
    }
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}
