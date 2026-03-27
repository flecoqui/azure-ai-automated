@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The name of the Azure ML workspace.')
param azureMLName string

@description('The resource ID of the Azure Container Registry.')
param acrId string

@description('The resource ID of the Application Insights instance.')
param appInsightsId string

@description('The resource ID of the storage account for Azure ML.')
param storageId string

@description('Resource ID of the Azure Key Vault.')
param keyVaultId string

@description('The tags to be applied to the provisioned resources.')
param tags object



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
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

output outAzureMLName string = azureML.name
output outAzureMLId string = azureML.id
