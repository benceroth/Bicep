using '../main.bicep'

// ═══════════════════════════════════════════════════════════════════════════
// Development environment parameters
// ═══════════════════════════════════════════════════════════════════════════

param projectName = 'broth123'
param environmentName = 'Development'

// ── Feature flags ──
param enableCosmos = true
param enableFunctionApp = true
param enableAppService = true
param enableFrontDoor = true
param enableAlerts = true
param enableServiceBus = true
param enableBotService = true

// ── Cosmos DB ──
param cosmosContainerName = 'demo'
param cosmosUseFreeTier = true
param cosmosThroughputLimit = 1000

// ── Alerts ──
param actionGroupShortName = 'Demo AG'
param actionGroupEmailAddress = 'info@broth.hu'

// ── Front Door ──
param customDomainHost = 'custom.sample.domain'

// ── Log Analytics ──
param logCapacityPerDay = 1

// ── Function App ──
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '10.0'
param functionAppIdentityType = 'SystemAssigned'

// ── App Service ──
param appServiceRuntimeVersion = 'v10.0'

// ── Auth — overwrite in pipeline or CLI ──
param authClientId = ''
param authClientSecret = ''

// ── Bot Service — overwrite in pipeline or CLI ──
param botAuthClientSecret = ''
