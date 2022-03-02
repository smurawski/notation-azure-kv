targetScope = 'subscription'

param location string = 'eastus'
param k8sversion string = '1.19.6'
param rgName string = 'myakv-akv-rg'
param envPrefix string = 'myakv'


resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

module acr './acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'myakv-acr'
  params: {
    acrName: '${envPrefix}Acr'
    location: location
  }
}

module aks './aks.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'myakv-aks'
  params: {
    k8sversion: k8sversion
    location: location
  }
}

module keyvault './keyvault.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'myakv-kevault'
  params: {
    location: location
  }
}

output aks_name string = aks.outputs.clusterName
output acr_name string = acr.outputs.acrName
output keyVault_name string = keyvault.outputs.keyVaultName
