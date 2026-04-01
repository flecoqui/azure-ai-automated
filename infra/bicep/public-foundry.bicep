@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('Name of the Microsoft Foundry.')
param foundryName string

@description('Name of the Microsoft Foundry Project.')
param foundryProjectName string

@description('The tags to be applied to the provisioned resources.')
param tags object

/*
  An AI Foundry resources is a variant of a CognitiveServices/account resource type
*/ 
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    // required to work in AI Foundry
    allowProjectManagement: true
    // Defines developer API endpoint subdomain
    customSubDomainName: foundryName

    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

/*
  Developer APIs are exposed via a project, which groups in- and outputs that relate to one use case, including files.
  Its advisable to create one project right away, so development teams can directly get started.
  Projects may be granted individual RBAC permissions and identities on top of what account provides.
*/ 
resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: foundryProjectName
  parent: aiFoundry
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
  tags: tags
}

/*
  Optionally deploy a model to use in playground, agents and other tools.
*/
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01'= {
  parent: aiFoundry
  name: 'gpt-4.1-mini'
  sku : {
    capacity: 1
    name: 'GlobalStandard'
  }
  properties: {
    model:{
      name: 'gpt-4.1-mini'
      format: 'OpenAI'
      version: '2025-04-14'
    }
  }
  tags: tags
}

output foundryName string = aiFoundry.name
output foundryId string = aiFoundry.id
output projectName string = aiProject.name
output projectId string = aiProject.id
output modelDeploymentName string = modelDeployment.name  
output modelDeploymentId string = modelDeployment.id
output modelDeploymentUri string = aiFoundry.properties.endpoint
// If keys are enabled on the Foundry account, they will be output here.
// output modelDeploymentKey string = listKeys(aiFoundry.id, aiFoundry.apiVersion).key1
output modelDeploymentKey string = ''
output modelDeploymentModelApiVersion string = modelDeployment.properties.model.version 
output modelDeploymentModelName string = modelDeployment.properties.model.name

