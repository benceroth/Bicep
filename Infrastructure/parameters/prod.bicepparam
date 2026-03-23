using '../main.bicep'

// ═══════════════════════════════════════════════════════════════════════════
// Production environment parameters
// ═══════════════════════════════════════════════════════════════════════════

param projectName = 'myproject-prod'
param environmentName = 'Production'

// ── Feature flags ──
param enableCosmos = true
param enableFunctionApp = true
param enableAppService = true
param enableFrontDoor = true
param enableAlerts = true
param enableServiceBus = true

// ── Cosmos DB ──
param cosmosContainerName = 'data'
param cosmosUseFreeTier = false
param cosmosThroughputLimit = 10000

// ── Alerts ──
param actionGroupShortName = 'Prod AG'
param actionGroupEmailAddress = 'prod-alerts@example.com'

// ── Front Door ──
param customDomainHost = 'app.example.com'

// ── Log Analytics ──
param logCapacityPerDay = 10

// ── Function App ──
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '8.0'
param functionAppIdentityType = 'SystemAssigned'

// ── App Service ──
param appServiceRuntimeVersion = 'v8.0'

// ── Auth — overwrite in pipeline ──
param authClientId = ''
param authClientSecret = ''
