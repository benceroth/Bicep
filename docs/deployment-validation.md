# Deployment Validation Checklist

Use this checklist after every deployment to confirm the infrastructure is healthy.
Referenced from `README.md` deployment instructions and `scripts/deploy.ps1`.

## Pre-Deployment

- [ ] Azure CLI installed and logged in (`az login`)
- [ ] Correct subscription selected (`az account set --subscription <id>`)
- [ ] Target resource group exists with **Contributor** + **RBAC Administrator** roles
- [ ] Correct parameter file chosen for the target environment (`dev`, `staging`, `prod`)
- [ ] Secrets prepared for deploy-time injection (`authClientId`, `authClientSecret`, `botAuthClientSecret`)

## Deployment Execution

Run one of:

```bash
# CLI — recommended
az deployment group create \
  --resource-group <rg-name> \
  --template-file Infrastructure/main.bicep \
  --parameters @Infrastructure/parameters/<env>.bicepparam \
  --parameters authClientId=<value> authClientSecret=<value>

# PowerShell script
.\scripts\deploy.ps1 -Environment <env> -ResourceGroup <rg-name> -Location westeurope
```

- [ ] Deployment command completed with exit code 0
- [ ] Deployment name appears in the Azure Portal under Resource Group → Deployments

## Post-Deployment Validation

### Core Resources (always deployed)

| Resource | Validation | CLI Check |
|----------|-----------|-----------|
| **VNet** | Exists with 4 subnets (`snet-pes`, `snet-fas`, `snet-web`, `snet-ampls`) | `az network vnet subnet list --resource-group <rg> --vnet-name vnet-<project> -o table` |
| **NSG** | Attached to all subnets, 4 rules present | `az network nsg rule list --resource-group <rg> --nsg-name nsg-<project> -o table` |
| **Log Analytics** | Workspace provisioned, daily cap set | `az monitor log-analytics workspace show --resource-group <rg> --workspace-name law-<project> --query "sku"` |
| **Storage Account** | Public access disabled, RBAC-only, TLS 1.2+ | `az storage account show --name st<project> --query "{publicAccess:publicNetworkAccess, tlsVersion:minimumTlsVersion, sharedKey:allowSharedKeyAccess}"` |
| **Key Vault** | RBAC enabled, public access disabled, soft-delete on | `az keyvault show --name kv-<project> --query "{rbac:properties.enableRbacAuthorization, publicAccess:properties.publicNetworkAccess, softDelete:properties.enableSoftDelete}"` |

### Private Endpoints (always deployed for KV & Storage; conditional for Cosmos & Service Bus)

- [ ] Private endpoint resources exist in `snet-pes`
- [ ] Private DNS zones created (`privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`, etc.)
- [ ] VNet links connect DNS zones to the VNet

```bash
az network private-endpoint list --resource-group <rg> -o table
az network private-dns zone list --resource-group <rg> -o table
```

### Optional Resources (verify only if feature flag was enabled)

| Feature Flag | Resource | Validation |
|---|---|---|
| `enableCosmos` | Cosmos DB account | `az cosmosdb show --name cosmos-<project> --resource-group <rg> --query "{publicAccess:publicNetworkAccess, consistency:consistencyPolicy.defaultConsistencyLevel}"` |
| `enableServiceBus` | Service Bus namespace | `az servicebus namespace show --name sb-<project> --resource-group <rg> --query "{sku:sku.name, publicAccess:publicNetworkAccess, tls:minimumTlsVersion}"` |
| `enableFunctionApp` | Function App + App Insights + ASP | `az functionapp show --name fa-<project> --resource-group <rg> --query "{state:state, httpsOnly:httpsOnly, ftps:siteConfig.ftpsState}"` |
| `enableAppService` | App Service + App Insights | `az webapp show --name app-<project> --resource-group <rg> --query "{state:state, httpsOnly:httpsOnly}"` |
| `enableFrontDoor` | Front Door profile + WAF policy | `az afd profile show --profile-name afd-<project> --resource-group <rg> --query "{sku:sku.name, provisioningState:provisioningState}"` |
| `enableBotService` | Bot Service + Bot Host App Service | `az bot show --name bot-<project> --resource-group <rg> --query "{endpoint:properties.endpoint, sku:sku.name}"` |
| `enableAlerts` | Action Group + Alert Rules | `az monitor action-group show --name ag-<project> --resource-group <rg> --query "{emailReceivers:emailReceivers[].emailAddress}"` |

### RBAC Assignments

RBAC propagation can take **up to 5 minutes** after deployment completes. Verify key assignments:

```bash
# Function App identity → Storage Blob Data Contributor
az role assignment list --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/st<project> \
  --query "[?roleDefinitionName=='Storage Blob Data Contributor'].{principal:principalName, role:roleDefinitionName}" -o table

# Function App identity → Key Vault Secrets User
az role assignment list --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/kv-<project> \
  --query "[?roleDefinitionName=='Key Vault Secrets User'].{principal:principalName, role:roleDefinitionName}" -o table
```

### Diagnostics

- [ ] Storage Account sends metrics to Log Analytics
- [ ] Key Vault sends `allLogs` + `AllMetrics` to Log Analytics
- [ ] Cosmos DB sends diagnostics to Log Analytics (if enabled)
- [ ] Service Bus sends diagnostics to Log Analytics (if enabled)

```bash
az monitor diagnostic-settings list --resource /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/kv-<project> -o table
```

## Post-Deploy Manual Steps

These cannot be automated via Bicep and must be completed after deployment:

### Bot Service (if `enableBotService = true`)

1. Navigate to **Azure Portal → Entra ID → App registrations → (bot app) → Certificates & secrets → Federated credentials**
2. Add a federated credential:
   - **Scenario**: Managed identity
   - **Managed identity**: select `uai-bot-<project>`
   - Issuer, subject, and audience are populated automatically
3. For SSO, ensure the `botSsoClientId` app registration has correct redirect URIs per the [Azure Bot SSO guide](https://learn.microsoft.com/en-us/azure/bot-service/bot-builder-concept-identity-providers)

### Front Door Custom Domain (if `enableFrontDoor = true`)

1. Add a CNAME record for the custom domain pointing to the Front Door endpoint hostname
2. Validate domain ownership in the Azure Portal under Front Door → Custom domains

### App Service Auth (if `authClientId` was provided)

1. Verify Entra ID app registration has correct redirect URIs pointing to the App Service hostname
2. Test authentication flow by navigating to the App Service URL

## Troubleshooting Common Issues

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| Deployment fails on role assignment | RBAC propagation delay from a previous deployment | Wait 60 seconds and retry; role assignments are idempotent |
| Function App cannot read Key Vault secrets | Managed identity RBAC not yet propagated | Wait up to 5 minutes; verify role assignment exists (see RBAC section above) |
| Private endpoint DNS not resolving | VNet link missing or DNS zone not connected | Check `az network private-dns zone list` and verify VNet links exist |
| Front Door origin returns 403 | App Service IP restriction blocking Front Door | Verify the `X-Azure-FDID` header restriction matches the Front Door ID |
| Cosmos DB operations return 401 | `disableLocalAuth: true` requires RBAC; SQL role assignment may be missing | Verify Cosmos SQL role assignment for the Function App principal |
| Service Bus connection refused | Premium SKU required for private endpoints; Basic/Standard won't work | Check `serviceBusSku` parameter — must be `Premium` if private endpoints are needed |
| Bot Service not responding | Federated identity credential not configured (manual step) | Complete the post-deploy federated credential setup |
| Alert emails not received | Action Group email address incorrect or unconfirmed | Check `actionGroupEmailAddress` in the parameter file |
