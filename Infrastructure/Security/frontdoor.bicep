param environmentName string
param projectName string

param frontDoorName string
param wafPolicyName string
param frontDoorSkuName string = 'Standard_AzureFrontDoor'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2025-06-01' = {
  name: frontDoorName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
  properties: {
    originResponseTimeoutSeconds: 240
  }
  tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = {
  name: frontDoorName
  parent:frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2025-03-01' = {
  name: wafPolicyName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
    }
    customRules: {
      rules: [
        {
          name: 'RateLimiting'
          enabledState: 'Enabled'
          priority: 1
          ruleType: 'RateLimitRule'
          rateLimitDurationInMinutes: 5
          rateLimitThreshold: 1000
          matchConditions: [
            {
              matchVariable: 'RequestHeader'
              selector: 'Host'
              operator: 'GreaterThanOrEqual'
              negateCondition: false
              matchValue: [
                '0'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
      ]
    }
  }
    tags: {
    Project: projectName
    Environment: environmentName
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2025-06-01' = {
  parent: frontDoorProfile
  name: '${wafPolicyName}securitypolicy'
  properties: {
    parameters: {
      wafPolicy: {
        id: wafPolicy.id
      }
      type:'WebApplicationFirewall'
      associations: [
        {
          domains: [
            {
            id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

output frontDoorName string = frontDoorName
output frontDoorEndpointName string = frontDoorEndpoint.name
output frontDoorId string = frontDoorProfile.properties.frontDoorId
output frontDoorUrl string = frontDoorEndpoint.properties.hostName
