@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The base name to be appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('The name of the Azure ML workspace.')
param azureMLName string

@description('The name of the Azure ML compute instance.')
param computeInstanceName string

@description('The name of the virtual network for virtual network integration.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('The name of the resource group containing the virtual network.')
param vnetResourceGroupName string

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

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The VM size for the Azure ML compute instance CPU based.')
param computeInstanceCPUSize string = 'Standard_DS11_v2'

@description('The VM size for the Azure ML compute instance GPU based.')
param computeInstanceGPUSize string = 'Standard_NC4as_T4_v3'

@description('The resource ID of the Azure AI Foundry account for managed network private endpoint.')
param foundryId string

@description('The tags to be applied to the provisioned resources.')
param tags object

var privateSubnetId = '${resourceId(vnetResourceGroupName,'Microsoft.Network/virtualNetworks', vnetName)}/subnets/${subnetName}'

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
    publicNetworkAccess: 'Disabled'
    systemDatastoresAuthMode: 'identity'
    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
      outboundRules: {
        // PyPI – pip install
        'allow-pypi': {
          type: 'FQDN'
          destination: 'pypi.org'
          category: 'UserDefined'
        }
        'allow-pypi-files': {
          type: 'FQDN'
          destination: 'files.pythonhosted.org'
          category: 'UserDefined'
        }
        // Conda / conda-forge
        'allow-conda': {
          type: 'FQDN'
          destination: 'conda.anaconda.org'
          category: 'UserDefined'
        }
        'allow-anaconda': {
          type: 'FQDN'
          destination: 'repo.anaconda.com'
          category: 'UserDefined'
        }
        // PyTorch wheel index + CDN
        'allow-pytorch': {
          type: 'FQDN'
          destination: 'pytorch.org'
          category: 'UserDefined'
        }
        'allow-pytorch-download': {
          type: 'FQDN'
          destination: 'download.pytorch.org'
          category: 'UserDefined'
        }
        'allow-pytorch-cdn': {
          type: 'FQDN'
          destination: '*.pytorch.org'
          category: 'UserDefined'
        }
        // HuggingFace model/dataset downloads
        'allow-huggingface': {
          type: 'FQDN'
          destination: 'huggingface.co'
          category: 'UserDefined'
        }
        'allow-huggingface-cdn': {
          type: 'FQDN'
          destination: '*.hf.co'
          category: 'UserDefined'
        }
        'openai-foundry': {
          type: 'FQDN'
          destination: '*.cognitiveservices.azure.com'
          category: 'UserDefined'
        }
        'inference-ml': {
          type: 'FQDN'
          destination: '*.inference.ml.azure.com'
          category: 'UserDefined'
        }
        // Azure AI Foundry evaluation / red-team service (FQDN for internet path)
        'allow-ai-services': {
          type: 'FQDN'
          destination: '*.services.ai.azure.com'
          category: 'UserDefined'
        }
        // Private endpoint to Foundry account (bypasses public network access block)
        'foundry-account-pe': {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: foundryId
            subresourceTarget: 'account'
            sparkEnabled: false
            sparkStatus: 'Inactive'
          }
          category: 'UserDefined'
        }
      }
    }
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
      // subnet: {
      //   id: privateSubnetId
      //}
      // Assign the CI to a specific user (common in enterprise setups)
      personalComputeInstanceSettings: {
        assignedUser: {
          objectId: objectId
          tenantId: tenantId
        }
      }
    }
  }
  dependsOn: [
    azmlPrivateEndpoint
  ]
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
      // subnet: {
      //  id: privateSubnetId
      // }
      // Assign the CI to a specific user (common in enterprise setups)
      personalComputeInstanceSettings: {
        assignedUser: {
          objectId: objectId
          tenantId: tenantId
        }
      }
    }
  }
  dependsOn: [
    azmlPrivateEndpoint
  ]
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
