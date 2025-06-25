param keyVaultName string
param secretNames string[]
param secretValues string[]

resource vault 'Microsoft.KeyVault/vaults@2024-12-01-preview' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2024-12-01-preview' = [for (secretName, i) in secretNames: {
  parent: vault
  name: secretName
  properties: {
    value: secretValues[i]
    attributes: {
      enabled: true
    }
  }
}]
