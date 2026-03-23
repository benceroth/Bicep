# Architecture Overview

This document visualises the modular Azure architecture deployed by `Infrastructure/main.bicep`.

## System Topology

```mermaid
flowchart TB
    subgraph Orchestrator["main.bicep — Feature-Flagged Orchestrator"]
        direction TB
        FF["Feature Flags\nenableCosmos · enableFunctionApp\nenableAppService · enableFrontDoor\nenableAlerts · enableServiceBus\nenableBotService"]
    end

    Orchestrator -->|always| NET
    Orchestrator -->|always| LOG
    Orchestrator -->|always| STG
    Orchestrator -->|always| KV
    Orchestrator -->|enableCosmos| CDB
    Orchestrator -->|enableServiceBus| SB
    Orchestrator -->|enableFunctionApp| FA
    Orchestrator -->|enableAppService| APP
    Orchestrator -->|enableBotService| BOT_HOST
    Orchestrator -->|enableBotService| BOT_SVC
    Orchestrator -->|enableFrontDoor| AFD
    Orchestrator -->|"enableFrontDoor ∧ enableAppService"| AFD_ORIGIN
    Orchestrator -->|enableAlerts| ALERTS

    subgraph VNET["VNet — 10.0.0.0/16"]
        subgraph PE_SUB["snet-pes · 10.0.0.0/24\nPrivate Endpoints"]
            PE_KV["pe-kv\nKey Vault"]
            PE_STG["pe-st\nStorage"]
            PE_CDB["pe-cosmos\nCosmos DB"]
            PE_SB["pe-sb\nService Bus"]
        end
        subgraph FA_SUB["snet-fas · 10.0.1.0/24\nFunction App Delegation"]
            FA["Function App\n.NET / PowerShell / Node\nSystemAssigned or UserAssigned MI"]
        end
        subgraph WEB_SUB["snet-web · 10.0.2.0/24\nApp Service Delegation"]
            APP["App Service\n.NET 10 · Entra ID Auth"]
            BOT_HOST["Bot Host App Service\n.NET 10 · Agent SDK\nUserAssigned MI"]
        end
        subgraph AMPLS_SUB["snet-ampls · 10.0.3.0/24\nMonitoring"]
        end
        NSG["NSG\nAllow HTTPS intra-VNet\nDeny all other inbound\nDeny all other outbound"]
    end

    subgraph DATA["Data Plane"]
        LOG["Log Analytics\nWorkspace\n30-day retention"]
        STG["Storage Account\nZRS · RBAC-only\nTLS 1.2+ · Infra encryption"]
        KV["Key Vault\nRBAC · Soft-delete\nPurge protection"]
        CDB["Cosmos DB\nSQL API · Serverless\nBoundedStaleness"]
        SB["Service Bus\nPremium · Zone-redundant"]
    end

    subgraph SECURITY["Security / Edge"]
        AFD["Front Door\nStandard SKU\nGlobal endpoint"]
        WAF["WAF Policy\nPrevention mode\nRate limiting 1000/5min"]
        AFD_ORIGIN["Origin + Route\nHTTPS-only · Auto-redirect\nCustom domain"]
        AFD --- WAF
        AFD --- AFD_ORIGIN
    end

    subgraph OBS["Observability"]
        ALERTS["Action Group · Email\nLog Alerts · KQL\nService Health Alert"]
    end

    subgraph BOT["Bot Service"]
        BOT_SVC["Azure Bot Service\nTeams channel · SSO\nFederated identity"]
    end

    %% Data-plane private access
    KV -.->|private endpoint| PE_KV
    STG -.->|private endpoint| PE_STG
    CDB -.->|private endpoint| PE_CDB
    SB -.->|private endpoint| PE_SB

    %% Compute → Data RBAC
    FA -->|"RBAC: Blob Contributor\nKV Secrets User\nKV Reader\nMetrics Publisher\nCosmos Contributor\nSB Data Receiver"| DATA
    APP -->|RBAC: KV Secrets User| KV

    %% Edge → Compute
    AFD_ORIGIN -->|origin| APP

    %% Bot wiring
    BOT_HOST -->|messaging endpoint| BOT_SVC

    %% Diagnostics
    STG -.->|diagnostics| LOG
    KV -.->|diagnostics| LOG
    CDB -.->|diagnostics| LOG
    SB -.->|diagnostics| LOG

    NET["network.bicep"]

    classDef flag fill:#fff3cd,stroke:#856404
    classDef always fill:#d4edda,stroke:#155724
    classDef optional fill:#cce5ff,stroke:#004085
    classDef security fill:#f8d7da,stroke:#721c24

    class FF flag
    class NET,LOG,STG,KV always
    class CDB,SB,FA,APP,BOT_HOST,BOT_SVC,AFD,WAF,AFD_ORIGIN,ALERTS optional
```

## Module Dependency Graph

```mermaid
flowchart LR
    main["main.bicep"] --> network["network.bicep"]
    main --> log["Data/log.bicep"]
    main --> storage["Data/storage.bicep"]
    main --> keyvault["Data/keyvault.bicep"]
    main --> kvsecret["Data/keyvault-secret.bicep"]
    main --> cosmos["Data/cosmosdb.bicep"]
    main --> servicebus["Data/servicebus.bicep"]
    main --> functionapp["Modules/functionapp.bicep"]
    main --> appservice["Modules/appservice.bicep"]
    main --> botappservice["Modules/botappservice.bicep"]
    main --> botservice["Modules/botservice.bicep"]
    main --> frontdoor["Security/frontdoor.bicep"]
    main --> frontdoororigin["Security/frontdoor-origin.bicep"]
    main --> actiongroup["Alerts/actiongroup.bicep"]
    main --> logalert["Alerts/logalert-appinsights.bicep"]
    main --> activityalert["Alerts/activityalert-servicehealth.bicep"]

    network -->|vnetName| storage
    network -->|vnetName| keyvault
    network -->|vnetName| cosmos
    network -->|vnetName| servicebus
    network -->|vnetName| functionapp
    network -->|vnetName| appservice
    network -->|vnetName| botappservice

    log -->|logWorkspaceName| storage
    log -->|logWorkspaceName| keyvault
    log -->|logWorkspaceName| cosmos
    log -->|logWorkspaceName| servicebus
    log -->|logWorkspaceName| functionapp
    log -->|logWorkspaceName| appservice
    log -->|logWorkspaceName| botappservice
    log -->|logWorkspaceName| botservice

    storage -->|storageAccountName| functionapp
    keyvault -->|keyVaultName| kvsecret
    keyvault -->|keyVaultName| functionapp
    keyvault -->|keyVaultName| appservice
    keyvault -->|keyVaultName| botappservice

    cosmos -->|cosmosAccountName| functionapp
    servicebus -->|serviceBusNamespaceName| functionapp

    frontdoor -->|frontDoorId, frontDoorUrl| appservice
    frontdoor -->|frontDoorName, endpointName| frontdoororigin
    appservice -->|appServiceHostName| frontdoororigin

    botappservice -->|hostName, appInsights| botservice
    functionapp -->|appinsightsName, functionAppName| logalert
    appservice -->|appinsightsName, appServiceName| logalert
    botappservice -->|appinsightsName, botAppServiceName| logalert

    classDef core fill:#d4edda,stroke:#155724
    classDef data fill:#cce5ff,stroke:#004085
    classDef compute fill:#fff3cd,stroke:#856404
    classDef security fill:#f8d7da,stroke:#721c24
    classDef obs fill:#e2e3e5,stroke:#383d41

    class main core
    class network core
    class log,storage,keyvault,kvsecret,cosmos,servicebus data
    class functionapp,appservice,botappservice,botservice compute
    class frontdoor,frontdoororigin security
    class actiongroup,logalert,activityalert obs
```

## Private Endpoint & DNS Pattern

Every data-plane service follows the same four-resource pattern inside `snet-pes`:

| # | Resource | Purpose |
|---|----------|---------|
| 1 | Service (e.g. Key Vault) | The actual Azure resource with `publicNetworkAccess: 'Disabled'` |
| 2 | Private Endpoint (`pe-*`) | NIC in `snet-pes` linked to the service via `privateLinkServiceConnections` |
| 3 | Private DNS Zone (`privatelink.*`) | Resolves the service FQDN to the private IP |
| 4 | VNet Link (`pdz-*-link`) | Connects the DNS zone to the VNet for automatic resolution |

Services using this pattern: **Key Vault**, **Storage Account**, **Cosmos DB**, **Service Bus**.

## Subnet Purpose Matrix

| Subnet | CIDR | Delegation | Hosts |
|--------|------|------------|-------|
| `snet-pes` | 10.0.0.0/24 | None | Private endpoints for KV, Storage, Cosmos, Service Bus |
| `snet-fas` | 10.0.1.0/24 | `Microsoft.Web/serverFarms` | Function App VNet integration |
| `snet-web` | 10.0.2.0/24 | `Microsoft.Web/serverFarms` | App Service + Bot Host App Service VNet integration |
| `snet-ampls` | 10.0.3.0/24 | None | Azure Monitor Private Link Scope (reserved) |

## NSG Rules Summary

| Rule | Direction | Priority | Source / Dest | Port | Action |
|------|-----------|----------|---------------|------|--------|
| AllowVnetHTTPSInbound | Inbound | 100 | VirtualNetwork → VirtualNetwork | 443 | Allow |
| DenyAllInbound | Inbound | 4096 | * → * | * | Deny |
| AllowVnetHTTPSOutbound | Outbound | 100 | VirtualNetwork → VirtualNetwork | 443 | Allow |
| DenyAllOutbound | Outbound | 4096 | * → * | * | Deny |

## RBAC Role Assignments

The Function App module assigns these roles to its managed identity:

| Role | Scope | Well-known ID |
|------|-------|---------------|
| Storage Blob Data Contributor | Storage Account | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |
| Monitoring Metrics Publisher | Application Insights | `3913510d-42f4-4e42-8a64-420c390055eb` |
| Key Vault Secrets User | Key Vault | `4633458b-17de-408a-b874-0445c86b69e6` |
| Key Vault Reader | Key Vault | `21090545-7ca7-4776-b22c-e363652d74d2` |
| Cosmos DB Contributor (SQL) | Cosmos DB Account | Built-in `00000000-…-000002` |
| Service Bus Data Receiver | Service Bus Namespace | `4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0` |
