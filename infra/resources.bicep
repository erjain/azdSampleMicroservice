param name string
param location string
param principalId string = ''
param resourceToken string
param tags object
param backendImageName string = ''
param frontendImageName string = ''

param uniqueSeed string = name



resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: 'contreg${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'keyvault${resourceToken}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
  }

}

resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = if (!empty(principalId)) {
  name: '${keyVault.name}/add'
  properties: {
    accessPolicies: [
      {
        objectId: principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
        tenantId: subscription().tenantId
      }
    ]
  }
}

module appInsightsResources './appinsights.bicep' = {
  name: 'appinsights-${resourceToken}'
  params: {
    resourceToken: resourceToken
    location: location
    tags: tags
  }
}

////////////////////////////////////////////////////////////////////////////////
// Infrastructure
////////////////////////////////////////////////////////////////////////////////

module containerAppsEnvironment 'modules/infra/container-apps-env.bicep' = {
  name: 'cae-${resourceToken}'
  params: {
    location: location
    uniqueSeed: uniqueSeed
  }
}


////////////////////////////////////////////////////////////////////////////////
// Container apps
////////////////////////////////////////////////////////////////////////////////

module backend 'modules/apps/backend.bicep' = {
  name: '${deployment().name}-app-backend'
  dependsOn: [
    containerAppsEnvironment
    containerRegistry
    appInsightsResources
    keyVault
  ]
  params: {
    name:name
    location: location
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.id
    containerAppsEnvironmentDomain: containerAppsEnvironment.outputs.domain
    imageName: backendImageName != '' ? backendImageName : 'nginx:latest'
  }
}
module frontend 'modules/apps/frontend.bicep' = {
  name: '${deployment().name}-app-frontend'
  dependsOn: [
    containerAppsEnvironment
    containerRegistry
    appInsightsResources
    keyVault
    backend
  ]
  params: {
    name:name
    location: location
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.id
    containerAppsEnvironmentDomain: containerAppsEnvironment.outputs.domain
    imageName: frontendImageName != '' ? frontendImageName : 'nginx:latest'
  }
}



output AZURE_KEY_VAULT_ENDPOINT string = keyVault.properties.vaultUri
output APPINSIGHTS_INSTRUMENTATIONKEY string = appInsightsResources.outputs.APPINSIGHTS_INSTRUMENTATIONKEY
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output API_URI string = backend.outputs.API_URI
output WEB_URI string = frontend.outputs.WEB_URI
