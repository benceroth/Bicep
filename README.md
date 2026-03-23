# Enterprise-Grade Bicep IaC Reference Project

## Overview
This repository provides an **enterprise-grade Infrastructure as Code (IaC) reference implementation using Bicep** for deploying secure, scalable, and production-ready Azure resources. It follows modular design principles, secure-by-default configurations, and least privilege access controls.

Clone the entire repo for each use-case, customise the parameter files for your environment, toggle feature flags to include only the components you need, and deploy.

## Key Features
- Modular Bicep architecture for scalability and reuse
- **Feature flags** — enable/disable components (Cosmos, Function App, App Service, Front Door, Alerts, Service Bus, Bot Service)
- **Consolidated modules** — single `functionapp.bicep` and `appservice.bicep` replace multiple variants
- **Environment overlays** — parameter files per environment (`dev`, `staging`, `prod`)
- Secure-by-default configurations & least privilege RBAC
- Private Endpoints and Private DNS Zones
- Managed and User Assigned Identity support (configurable per deployment)
- CI/CD pipeline (GitHub Actions) and deployment script (PowerShell)

---

## Repository Structure

```
Infrastructure/
├── main.bicep                  # Orchestrator with feature flags
├── main.bicepparam             # Legacy param file (backward compat)
├── network.bicep               # VNet + NSG + subnets
├── parameters/
│   ├── dev.bicepparam          # Development environment
│   ├── staging.bicepparam      # Staging environment
│   └── prod.bicepparam         # Production environment
├── Modules/
│   ├── functionapp.bicep       # Unified Function App (MI/UAI, dotnet/powershell)
│   ├── appservice.bicep        # Unified App Service (±Front Door, ±auth)
│   ├── botappservice.bicep     # Dedicated Bot Host App Service (.NET 10)
│   └── botservice.bicep        # Azure Bot Service + Teams + SSO
├── Data/
│   ├── log.bicep               # Log Analytics workspace
│   ├── storage.bicep           # Storage Account + private endpoints
│   ├── keyvault.bicep          # Key Vault + private endpoint
│   ├── keyvault-secret.bicep   # Key Vault secrets helper
│   └── cosmosdb.bicep          # Cosmos DB + private endpoint
├── Security/
│   ├── frontdoor.bicep         # Front Door profile + WAF
│   └── frontdoor-origin.bicep  # Front Door origin/route/custom domain
├── Alerts/
│   ├── actiongroup.bicep       # Action Group
│   ├── logalert-appinsights.bicep     # Log alert rule
│   └── activityalert-servicehealth.bicep  # Service Health alert
scripts/
└── deploy.ps1                  # Manual deployment script
.github/workflows/
└── deploy.yml                  # GitHub Actions CI/CD pipeline
```

---

## Feature Flags

Toggle components in your parameter file or via CLI overrides:

| Parameter           | Default | Description                              |
|---------------------|---------|------------------------------------------|
| `enableCosmos`      | `true`  | Deploy Cosmos DB resources               |
| `enableFunctionApp` | `true`  | Deploy a Function App                    |
| `enableAppService`  | `true`  | Deploy an App Service                    |
| `enableFrontDoor`   | `true`  | Deploy Azure Front Door and WAF          |
| `enableAlerts`      | `true`  | Deploy alert rules and action groups     |
| `enableServiceBus`  | `false` | Deploy Azure Service Bus namespace       |
| `enableBotService`  | `false` | Deploy Azure Bot Service with dedicated host |

Example — deploy without Cosmos or Front Door:

```bash
az deployment group create \
  --resource-group rg-myproject-dev \
  --template-file Infrastructure/main.bicep \
  --parameters @Infrastructure/parameters/dev.bicepparam \
  --parameters enableCosmos=false enableFrontDoor=false
```

---

## How to Deploy

### Prerequisites
- Azure CLI (Bicep CLI installed automatically)
- Azure Subscription with **Contributor** + **RBAC Administrator** on a Resource Group

### 1. Login to Azure
```bash
az login
az account set --subscription <your-subscription-id>
```

### 2. Choose an environment and deploy

**Using the parameter files (recommended):**

```bash
# Dev
az deployment group create \
  --resource-group rg-myproject-dev \
  --template-file Infrastructure/main.bicep \
  --parameters @Infrastructure/parameters/dev.bicepparam

# Staging
az deployment group create \
  --resource-group rg-myproject-stg \
  --template-file Infrastructure/main.bicep \
  --parameters @Infrastructure/parameters/staging.bicepparam

# Production
az deployment group create \
  --resource-group rg-myproject-prod \
  --template-file Infrastructure/main.bicep \
  --parameters @Infrastructure/parameters/prod.bicepparam
```

**Override secrets at deploy time:**

```bash
az deployment group create \
  --resource-group rg-myproject-dev \
  --template-file Infrastructure/main.bicep \
  --parameters @Infrastructure/parameters/dev.bicepparam \
  --parameters authClientId=<client-id> authClientSecret=<client-secret>
```

**Using the PowerShell script:**

```powershell
.\scripts\deploy.ps1 -Environment dev -ResourceGroup rg-myproject-dev -Location westeurope
```

### 3. CI/CD (GitHub Actions)

The workflow at `.github/workflows/deploy.yml` supports manual dispatch with environment selection. Configure these GitHub secrets and variables:

| Secret / Variable          | Scope       | Description                        |
|----------------------------|-------------|------------------------------------|
| `AZURE_CLIENT_ID`         | secret      | Service principal / federated app  |
| `AZURE_TENANT_ID`         | secret      | Entra ID tenant                    |
| `AZURE_SUBSCRIPTION_ID`   | secret      | Target subscription                |
| `AUTH_CLIENT_ID`           | secret      | App registration for Easy Auth     |
| `AUTH_CLIENT_SECRET`       | secret      | App registration secret            |
| `AZURE_RESOURCE_GROUP`    | variable    | Target resource group name         |

---

## Customising for a New Use-Case

1. **Clone** this repo into your project.
2. **Copy** `Infrastructure/parameters/dev.bicepparam` and rename for your environment.
3. **Edit** the parameter file — set `projectName`, toggle feature flags, adjust SKUs and thresholds.
4. **Add new modules** under `Infrastructure/Modules/`, `Data/`, `Security/`, or `Alerts/`, then wire them up in `main.bicep` behind a new feature flag.
5. **Deploy** using the CLI commands or CI/CD pipeline above.

---

## Module Outputs

Core modules now expose outputs for downstream consumption:

| Module              | Outputs                                                    |
|---------------------|------------------------------------------------------------|
| `network.bicep`     | `vnetId`, `vnetName`, `peSubnetId`, `faSubnetId`, `webSubnetId`, `amplsSubnetId` |
| `Data/log.bicep`    | `logWorkspaceId`, `logWorkspaceName`                       |
| `Data/storage.bicep`| `storageAccountId`, `storageAccountName`                   |
| `Data/keyvault.bicep`| `keyVaultId`, `keyVaultName`, `keyVaultUri`               |
| `Data/cosmosdb.bicep`| `cosmosAccountId`, `cosmosAccountName`                    |
| `Data/servicebus.bicep`| `serviceBusNamespaceId`, `serviceBusNamespaceName`      |
| `Security/frontdoor.bicep`| `frontDoorName`, `frontDoorEndpointName`, `frontDoorId`, `frontDoorUrl` |
| `Modules/functionapp.bicep`| `appinsightsName`, `functionAppName`, `functionAppPrincipalId` |
| `Modules/appservice.bicep`| `appinsightsName`, `appServiceName`, `appServiceHostName` |
| `Modules/botappservice.bicep`| `botAppServiceName`, `botAppServiceHostName`, `appinsightsName`, `appinsightsInstrumentationKey`, `appinsightsAppId` |
| `Modules/botservice.bicep`| `botServiceId`, `botServiceName`, `botMessagingEndpoint` |

---

## Bot Service — Post-Deploy Steps

The Bot Service uses a **user-assigned managed identity** for runtime authentication and a **separate Entra ID app registration** for Teams channel / SSO.

After deployment, you must manually configure a **Federated Identity Credential** on the Entra ID app registration used as the bot identity (`botMsaAppId`):

1. Navigate to **Azure Portal → Entra ID → App registrations → (your bot app) → Certificates & secrets → Federated credentials**.
2. Add a federated credential with:
   - **Federated credential scenario:** *Managed identity*
   - **Managed identity:** select the `uai-bot-<projectName>` identity created by the deployment.
   - **Issuer / Subject / Audience:** populated automatically.
3. Once saved the Bot Service can exchange tokens via the managed identity without storing secrets.

For SSO connections, also ensure the `botSsoClientId` app registration has the redirect URIs documented in the [Azure Bot SSO guide](https://learn.microsoft.com/en-us/azure/bot-service/bot-builder-concept-identity-providers).

---

## Security & Best Practices
- All resources configured with secure defaults
- NSGs applied to subnets with restrictive rules
- Private Endpoints enabled for supported services
- No public IPs exposed unnecessarily
- Managed Identities used for secure authentication
- Role-Based Access Control (RBAC) follows least privilege principles
- Tags and Diagnostic logging applied to resources for governance

---

## Adding New Modules

1. Create a new `.bicep` file under the appropriate folder (`Modules/`, `Data/`, `Security/`, or `Alerts/`).
2. Add a feature flag parameter (e.g., `enableMyService`) in `main.bicep`.
3. Wire the module call with `if (enableMyService)` in `main.bicep`.
4. Add the flag to your parameter files and set it per environment.

---

## License
This project is licensed under the [MIT License](LICENSE).

---

## Disclaimer
This repository is a reference implementation and is provided as-is. Always review, test, and adapt the configurations to meet your security and compliance requirements.

---

## Resources
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Security Best Practices](https://learn.microsoft.com/en-us/azure/security/fundamentals/)
- [Enterprise Scale Landing Zones](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/bicep/landing-zone-bicep)
