// dev.bicepparam
using '../storage.bicep'

param environment     = 'dev'
param appName         = 'myapp'          // ← change to your app name
param skuName         = 'Standard_LRS'  // Locally redundant for dev
param enableHns       = false
param allowedIpRanges = []              // Open in dev; restrict in prod