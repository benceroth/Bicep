# Environment Comparison: Dev → Staging → Prod

This document compares the three environment overlays defined in `Infrastructure/parameters/`.
Use it to understand cost, scaling, and feature-availability tradeoffs across environments.

## Feature Flags

| Feature Flag | Dev | Staging | Prod | Notes |
|---|:---:|:---:|:---:|---|
| `enableCosmos` | ✅ | ✅ | ✅ | Always on — core data store |
| `enableFunctionApp` | ✅ | ✅ | ✅ | Always on — primary compute |
| `enableAppService` | ✅ | ✅ | ✅ | Always on — web API host |
| `enableFrontDoor` | ✅ | ✅ | ✅ | Always on — global edge + WAF |
| `enableAlerts` | ✅ | ✅ | ✅ | Always on — observability baseline |
| `enableServiceBus` | ✅ | ✅ | ✅ | Always on — messaging layer |
| `enableBotService` | ✅ | ❌ | ❌ | Dev-only — experimental bot/AI feature |

**Design decision**: Bot Service is toggled off in staging and prod. This keeps cost and identity complexity low in higher environments until the bot workload is validated in dev.

## Scaling & Capacity

| Parameter | Dev | Staging | Prod | Scaling Pattern |
|---|---|---|---|---|
| **Cosmos throughput limit** | 1,000 RU | 4,000 RU | 10,000 RU | 4× dev → staging, 2.5× staging → prod |
| **Cosmos free tier** | ✅ Yes | ❌ No | ❌ No | Free tier only in dev (Azure limit: 1 per subscription) |
| **Log Analytics daily cap** | 1 GB/day | 5 GB/day | 10 GB/day | Progressive cap increase with environment criticality |
| **Service Bus SKU** | Premium | Premium | Premium | Always Premium for private endpoint support |
| **Bot SKU** | S1 (default) | N/A | N/A | Bot only deployed in dev |
| **Function App runtime** | dotnet-isolated 10.0 | dotnet-isolated 10.0 | dotnet-isolated 10.0 | Consistent across all environments |
| **App Service runtime** | v10.0 | v10.0 | v10.0 | Consistent across all environments |
| **Function App identity** | SystemAssigned | SystemAssigned | SystemAssigned | Same identity model per env |

## Naming Convention Per Environment

| Component | Dev | Staging | Prod |
|---|---|---|---|
| `projectName` | `myproject` | `myproject-stg` | `myproject-prod` |
| `environmentName` | `Development` | `Staging` | `Production` |
| Key Vault | `kv-myproject` | `kv-myproject-stg` | `kv-myproject-prod` |
| Storage | `stmyproject` | `stmyproject-stg` | `stmyproject-prod` |
| VNet | `vnet-myproject` | `vnet-myproject-stg` | `vnet-myproject-prod` |
| Cosmos DB | `cosmos-myproject` | `cosmos-myproject-stg` | `cosmos-myproject-prod` |
| Front Door | `afd-myproject` | `afd-myproject-stg` | `afd-myproject-prod` |
| Function App | `fa-myproject` | `fa-myproject-stg` | `fa-myproject-prod` |

## Secrets & Auth Strategy

| Parameter | Dev | Staging | Prod | Handling |
|---|---|---|---|---|
| `authClientId` | Empty in file | Empty in file | Empty in file | Injected at deploy time via CLI `--parameters` or GitHub Actions secret |
| `authClientSecret` | Empty in file | Empty in file | Empty in file | Same — never stored in parameter files |
| `botAuthClientSecret` | Empty in file | N/A | N/A | Same pattern; bot only in dev |
| `customDomainHost` | `custom.sample.domain` | `staging.example.com` | `app.example.com` | Per-environment Front Door custom domain |
| `actionGroupEmailAddress` | `info@broth.hu` | `staging-alerts@example.com` | `prod-alerts@example.com` | Separate alert recipients per environment |

**Key pattern**: Secrets are **never** committed to parameter files. They are injected at deploy time:
- **CLI**: `az deployment group create --parameters authClientId=<value> authClientSecret=<value>`
- **GitHub Actions**: Stored as repository secrets and passed as workflow parameters
- **PowerShell script**: `deploy.ps1 -AuthClientId <value> -AuthClientSecret <secure>`

## Cost Implications

| Service | Dev (est. monthly) | Staging | Prod | Primary Cost Driver |
|---|---|---|---|---|
| **Cosmos DB** | ~$0 (free tier) | ~$25–50 (serverless, 4K RU cap) | ~$50–150 (serverless, 10K RU cap) | Throughput cap + actual request volume |
| **Log Analytics** | ~$2.76 (1 GB × $2.76/GB) | ~$13.80 (5 GB cap) | ~$27.60 (10 GB cap) | Ingestion volume against daily cap |
| **Service Bus** | ~$668+ (Premium 1 MU) | ~$668+ (Premium 1 MU) | ~$668+ (Premium 1 MU) | Premium SKU is expensive; consider Standard for dev |
| **Front Door** | ~$35+ (Standard) | ~$35+ (Standard) | ~$35+ (Standard) | Base fee + per-request pricing |
| **Bot Service** | ~$0 (S1 included) | N/A | N/A | Disabled in staging/prod |
| **App Service Plan** | ~$73 (S1) | ~$73 (S1) | ~$73 (S1) | Default SKU across environments |
| **Key Vault** | ~$0.03/10K ops | ~$0.03/10K ops | ~$0.03/10K ops | Negligible at low operation volume |

> **Cost optimisation opportunity**: Service Bus Premium (~$668/mo) in dev is likely over-provisioned. Consider using `Standard` SKU for dev to save ~$600/mo. Note: private endpoints require Premium, so this trades cost for network isolation in dev.

## What Changes Between Environments

| Concern | What changes | What stays the same |
|---|---|---|
| **Cost** | Cosmos throughput cap, Log Analytics cap, bot enablement | Service Bus SKU, App Service Plan SKU, Front Door SKU |
| **Security** | Alert email recipients, custom domain hostname | NSG rules, private endpoints, RBAC model, TLS version, managed identities |
| **Features** | Bot Service availability | All other feature flags |
| **Identity** | None | SystemAssigned for Function App across all environments |
| **Runtime** | None | .NET 10 (isolated) everywhere |
