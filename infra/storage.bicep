// ============================================================
//  storage.bicep – Azure Storage Account
// ============================================================

targetScope = 'resourceGroup'

// ── Parameters ──────────────────────────────────────────────
@description('Deployment environment')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Azure region (defaults to resource group location)')
param location string = resourceGroup().location

@description('Base name used to build the storage account name (3–11 lowercase alphanum)')
@minLength(3)
@maxLength(11)
param appName string

@description('Storage redundancy – LRS for dev/staging, ZRS/GRS for prod')
@allowed(['Standard_LRS', 'Standard_ZRS', 'Standard_GRS', 'Standard_RAGRS'])
param skuName string = 'Standard_LRS'

@description('Enable hierarchical namespace (Data Lake Gen2)')
param enableHns bool = false

@description('Allowed IP ranges for network ACLs (empty = no restriction)')
param allowedIpRanges array = []

// ── Variables ────────────────────────────────────────────────
var suffix           = uniqueString(resourceGroup().id)
var storageAcctName  = 'st${appName}${environment}${take(suffix, 4)}'
var isProd           = environment == 'prod'

var commonTags = {
  environment: environment
  application: appName
  managedBy:   'bicep'
}

// ── Storage Account ──────────────────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name:     storageAcctName
  location: location
  tags:     commonTags
  sku: {
    name: isProd ? 'Standard_ZRS' : skuName   // Enforce ZRS in prod
  }
  kind: 'StorageV2'
  properties: {
    accessTier:               'Hot'
    allowBlobPublicAccess:    false            // No public blob access
    allowSharedKeyAccess:     true
    minimumTlsVersion:        'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled:             enableHns
    networkAcls: {
      defaultAction: empty(allowedIpRanges) ? 'Allow' : 'Deny'
      bypass:        'AzureServices'
      ipRules: [for ip in allowedIpRanges: {
        value:  ip
        action: 'Allow'
      }]
    }
  }
}

// ── Blob Service ─────────────────────────────────────────────
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name:   'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days:    isProd ? 30 : 7     // Longer retention in prod
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days:    isProd ? 30 : 7
    }
    isVersioningEnabled: isProd    // Versioning only in prod
  }
}

// ── Default container ────────────────────────────────────────
resource defaultContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name:   'app-data'
  properties: {
    publicAccess: 'None'
  }
}

// ── Outputs ──────────────────────────────────────────────────
output storageAccountName  string = storageAccount.name
output storageAccountId    string = storageAccount.id
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output resourceGroupName   string = resourceGroup().name
