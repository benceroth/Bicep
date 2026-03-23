param keyVaultName string
param secretNames string[]
param secretValues string[]

resource vault 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = [for (secretName, i) in secretNames: {
  parent: vault
  name: secretName
  properties: {
    value: secretValues[i]
    attributes: {
      enabled: true
    }
  }
}]
