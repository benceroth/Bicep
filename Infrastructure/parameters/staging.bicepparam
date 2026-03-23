using '../main.bicep'

// ═══════════════════════════════════════════════════════════════════════════
// Staging environment parameters
// ═══════════════════════════════════════════════════════════════════════════

param projectName = 'myproject-stg'
param environmentName = 'Staging'

// ── Feature flags ──
param enableCosmos = true
param enableFunctionApp = true
param enableAppService = true
param enableFrontDoor = true
param enableAlerts = true
param enableServiceBus = true
param enableBotService = false

// ── Cosmos DB ──
param cosmosContainerName = 'data'
param cosmosUseFreeTier = false
param cosmosThroughputLimit = 4000

// ── Alerts ──
param actionGroupShortName = 'Stg AG'
param actionGroupEmailAddress = 'staging-alerts@example.com'

// ── Front Door ──
param customDomainHost = 'staging.example.com'

// ── Log Analytics ──
param logCapacityPerDay = 5

// ── Function App ──
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '10.0'
param functionAppIdentityType = 'SystemAssigned'

// ── App Service ──
param appServiceRuntimeVersion = 'v10.0'

// ── Auth — overwrite in pipeline ──
param authClientId = ''
param authClientSecret = ''

// ── Bot Service — overwrite in pipeline ──
param botAuthClientSecret = ''
