# Enterprise-Grade Bicep IaC Reference Project

## Overview
This repository provides an **enterprise-grade Infrastructure as Code (IaC) reference implementation using Bicep** for deploying secure, scalable, and production-ready Azure resources. It follows modular design principles, secure-by-default configurations, and least privilege access controls.

## Key Features
✅ Modular Bicep architecture for scalability and reuse  
✅ Secure-by-default configurations  
✅ Least privilege access principles for identities and networking  
✅ Private Endpoints and Private DNS Zones  
✅ Managed and User Assigned Identities  
✅ Network Security Groups (NSGs) with granular rules  
✅ Production-ready Function App and App Service deployments  
✅ Supports enterprise security, governance, and compliance requirements  

## Deployment Prerequisites
- Azure CLI or PowerShell Az Module
- Bicep CLI (installed automatically with Azure CLI)
- Azure Subscription with Contributor and RBAC Administrator or higher permissions on a Resource Group

---

## How to Deploy
### 1. Login to Azure
```bash
az login
az account set --subscription <your-subscription-id>
```

### 2. Deploy Resources
Example for a Dev environment:
```bash
az deployment sub create \
  --location <location> \
  --template-file Infrastructure/main.bicep \
  --parameters @Infrastructure/main.bicepparam
```

---

## Security & Best Practices
✔ All resources configured with secure defaults  
✔ NSGs applied to subnets with restrictive rules  
✔ Private Endpoints enabled for supported services  
✔ No public IPs exposed unnecessarily  
✔ Managed Identities used for secure authentication  
✔ Role-Based Access Control (RBAC) follows least privilege principles  
✔ Tags and Diagnostic logging applied to resources for governance
---

## Supported Modules
- **Virtual Network (VNet)**
- **Network Security Groups (NSGs)**
- **Log analytics workspace**
- **Storage Account**
- **Key Vault**
- **Cosmos DB**
- **Function App**
- **App Service**
- **Application Insights**
- **Action Group**
- **Log Alert Rules**

## Next Steps
- Introduction of Front Door and other Azure services
- Make modules more customizable
- Provide sample code for the demo main.bicep infrastructure

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
