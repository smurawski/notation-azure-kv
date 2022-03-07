param location string = resourceGroup().location
param uaminame string = 'myakv-uami'
param kvName string = 'myakv-kv-${uniqueString(resourceGroup().id)}'

// Create a keyvault
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: uami.properties.principalId
        permissions: {
          keys: [
            'get'
            'sign'
          ]
          secrets: [
            'list'
            'get'
          ]
          certificates: [
            'get'
            'create'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

// create user assigned managed identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: uaminame
  location: location
}

output keyVaultName string = kvName
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
