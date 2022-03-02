param acrName string
param location string = resourceGroup().location

// param keyVaultId string

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic' 
  }
  properties: {
  adminUserEnabled: true
  }
}

output acrName string = acrName
