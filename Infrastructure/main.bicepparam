using './main.bicep'

// This file is kept for backward compatibility.
// For environment-specific parameters, see parameters/dev.bicepparam, staging.bicepparam, prod.bicepparam.

param actionGroupShortName = 'Demo AG'
param actionGroupEmailAddress = 'info@broth.hu'

param projectName = 'demoproject123test'
param environmentName = 'Development'

param cosmosContainerName = 'demo'
param cosmosUseFreeTier = true
param cosmosThroughputLimit = 1000

param customDomainHost = 'custom.sample.domain'

// App service Easy auth configuration, when empty it is turned off. Recommendation: overwrite these params in pipelines, cmd
param authClientId = ''
param authClientSecret = ''
