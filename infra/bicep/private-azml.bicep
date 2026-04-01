@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The base name to be appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('The name of the Azure ML workspace.')
param azureMLName string

@description('The name of the virtual network for virtual network integration.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('The resource ID of the Azure Container Registry.')
param acrId string

@description('The resource ID of the Application Insights instance.')
param appInsightsId string

@description('The resource ID of the storage account for Azure ML.')
param storageId string

@description('Resource ID of the Azure Key Vault.')
param keyVaultId string

@description('The Private DNS Zone id for the Azure ML API private endpoint.')
param azmlApiPrivateDnsZoneId string

@description('The Private DNS Zone id for the Azure ML Notebooks private endpoint.')
param azmlNotebooksPrivateDnsZoneId string

@description('The tags to be applied to the provisioned resources.')
param tags object

var privateSubnetId = '${resourceId('Microsoft.Network/virtualNetworks', vnetName)}/subnets/${subnetName}'

resource azureML 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: azureMLName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: azureMLName
    storageAccount: storageId
    keyVault: keyVaultId
    applicationInsights: appInsightsId
    containerRegistry: acrId
    publicNetworkAccess: 'Disabled'
  }
  tags: tags
}

resource azmlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: 'pe-azml-${baseName}'
  location: location
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-azml-${baseName}'
        properties: {
          privateLinkServiceId: azureML.id
          groupIds: [
            'amlworkspace'
          ]
        }
      }
    ]
  }

  resource azmlPrivateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'azmlPrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'api'
          properties: {
            privateDnsZoneId: azmlApiPrivateDnsZoneId
          }
        }
        {
          name: 'notebooks'
          properties: {
            privateDnsZoneId: azmlNotebooksPrivateDnsZoneId
          }
        }
      ]
    }
  }
}

output outAzureMLName string = azureML.name
output outAzureMLId string = azureML.id
