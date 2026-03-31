@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The name of the Azure ML workspace.')
param azureMLName string

@description('The name of the Azure ML compute instance.')
param computeInstanceName string

@description('The resource ID of the Azure Container Registry.')
param acrId string

@description('The resource ID of the Application Insights instance.')
param appInsightsId string

@description('The resource ID of the storage account for Azure ML.')
param storageId string

@description('Resource ID of the Azure Key Vault.')
param keyVaultId string

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The VM size for the Azure ML compute instance CPU based.')
param computeInstanceCPUSize string = 'Standard_DS11_v2'

@description('The VM size for the Azure ML compute instance GPU based.')
param computeInstanceGPUSize string = 'Standard_NC4as_T4_v3'

@description('The tags to be applied to the provisioned resources.')
param tags object

resource azureML 'Microsoft.MachineLearningServices/workspaces@2025-12-01' = {
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
    systemDatastoresAuthMode: 'identity'
  }
  tags: tags
}

var tenantId = subscription().tenantId
resource cicpu 'Microsoft.MachineLearningServices/workspaces/computes@2025-12-01' = {
  name: '${computeInstanceName}-cpu'
  parent: azureML
  location: location
  properties: {
    computeType: 'ComputeInstance'
    computeLocation: location
    properties: {
      vmSize: computeInstanceCPUSize
      idleTimeBeforeShutdown: 'PT1H'
      // Assign the CI to a specific user (common in enterprise setups)
      personalComputeInstanceSettings: {
        assignedUser: {
          objectId: objectId
          tenantId: tenantId
        }
      }
    }
  }
}

resource cigpu 'Microsoft.MachineLearningServices/workspaces/computes@2025-12-01' = {
  name: '${computeInstanceName}-gpu'
  parent: azureML
  location: location
  properties: {
    computeType: 'ComputeInstance'
    computeLocation: location
    properties: {
      vmSize: computeInstanceGPUSize
      idleTimeBeforeShutdown: 'PT1H'
      // Assign the CI to a specific user (common in enterprise setups)
      personalComputeInstanceSettings: {
        assignedUser: {
          objectId: objectId
          tenantId: tenantId
        }
      }
    }
  }
}

output outAzureMLName string = azureML.name
output outAzureMLId string = azureML.id
output outComputeInstanceCPUName string = cicpu.name
output outComputeInstanceCPUID string = cicpu.id
output outComputeInstanceGPUName string = cigpu.name
output outComputeInstanceGPUID string = cigpu.id