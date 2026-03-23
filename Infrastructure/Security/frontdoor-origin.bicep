param appHostName string

param customDomainHost string
param frontDoorName string
param frontDoorEndpointName string

resource frontDoorProfile 'Microsoft.Cdn/profiles@2025-06-01' existing = {
  name: frontDoorName
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' existing = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2025-06-01' = {
  name: frontDoorName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2025-06-01' = {
  name: frontDoorName
  parent: frontDoorOriginGroup
  properties: {
    hostName: appHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: appHostName
    priority: 1
    weight: 1000
  }
}

resource frontDoorCustomDomain 'Microsoft.Cdn/profiles/customDomains@2025-06-01' = { // Can be removed if custom domain is not needed
  name: '${frontDoorName}customdomain'
  parent: frontDoorProfile
  properties: {
    hostName: customDomainHost
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
    }
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2025-06-01' = {
  name: frontDoorName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    customDomains: [ // Can be removed if custom domain is not needed
      {
        id: frontDoorCustomDomain.id
      }
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}
