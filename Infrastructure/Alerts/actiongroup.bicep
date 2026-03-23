param actionGroupName string
param actionGroupShortName string
param actionGroupEmailAddress string

param environmentName string
param projectName string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      {
        name: 'Operation_-EmailAction-'
        emailAddress: actionGroupEmailAddress
      }
    ]
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}
