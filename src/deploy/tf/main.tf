variable "unique" {
  type = "string"
}
variable "project_name" {
  type = "string"
}
variable "operation_mode" {
  type = "string"
}
variable "resource_group" {
  type = "string"
}
variable "location" {
  type = "string"
}
variable "subscription_id" {
  type = "string"
}
variable "tenant_id" {
  type = "string"
}
variable "client_id" {
  type = "string"
}
variable "client_secret" {
  type = "string"
}
variable "boot_storage_account_uri" {
  type = "string"
}
variable "boot_storage_account_name" {
  type = "string"
}
variable "boot_storage_account_key" {
  type = "string"
}
variable "boot_storage_account_sas" {
  type = "string"
}
variable "custom_image_uri" {
  type = "string"
}

variable "consul_tenant_id" {
  type = "string"
}
variable "consul_client_id" {
  type = "string"
}
variable "consul_client_key" {
  type = "string"
}

# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version                   = "=1.20.0"
  client_id                 = "${var.client_id}"
  client_secret             = "${var.client_secret}"
  tenant_id                 = "${var.tenant_id}"
  subscription_id           = "${var.subscription_id}"
}
# data islands to use
data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

locals {
  key_vault_name  = "vaultkv${var.unique}" 
  key_vault_id    = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group}/providers/Microsoft.KeyVault/vaults/${local.key_vault_name}"
}

# create a resource group
resource "azurerm_resource_group" "main" {
  name                      = "${var.resource_group}"
  location                  = "${var.location}"
}
# create app insights workspace
resource "azurerm_application_insights" "insights" {
  name                        = "insights-ai-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  application_type            = "Web"
}
# create log analytis workspace
resource "azurerm_log_analytics_workspace" "analytics" {
  name                        = "analytics-log-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  sku                         = "Free"
}
resource "azurerm_storage_account" "storage" {
  name                        = "storagesa${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
}
resource "azurerm_eventgrid_topic" "status" {
  name                        = "status-evt-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
}
resource "azurerm_storage_account" "services" {
  name                        = "servicessa${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
}
resource "azurerm_app_service_plan" "services" {
  name                        = "services-asp-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  kind                        = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}
resource "azurerm_function_app" "services" {
  name                        = "services-app-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  app_service_plan_id         = "${azurerm_app_service_plan.services.id}"
  storage_connection_string   = "${azurerm_storage_account.services.primary_connection_string}"

  identity {
    type    = "SystemAssigned"
  }

  app_settings {
    "MERCATOR_DEBUG_MODE"            = "false"
    "MERCATOR_LOG_LEVEL"             = "15"
    "AZURE_SUBSCRIPTION_ID"           = "${var.subscription_id}"
    "RESOURCE_GROUP_NAME"             = "${var.resource_group}"
    "KEY_VAULT_URI"                   = "none"
    "STATUS_TOPIC_ID"                 = "${azurerm_eventgrid_topic.status.id}"
    "STORAGE_ACCOUNT_ID"              = "${azurerm_storage_account.storage.id}"
    "STATUS_TARGETS"                  = "[]"
    "APPINSIGHTS_INSTRUMENTATIONKEY"  = "${azurerm_application_insights.insights.instrumentation_key}"    
  }
}
resource "azurerm_template_deployment" "services_post" {
  name                = "services-post-deployment-${var.unique}"
  resource_group_name = "${var.resource_group}"
  deployment_mode     = "Incremental"
  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "functionAppName": {
      "type": "string"
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Web/sites/config",
      "name": "[concat(parameters('functionAppName'), '/web')]",
      "apiVersion": "2015-08-01",
      "properties": {
        "scmType": "LocalGit"        
      },
      "dependsOn": []
    }
  ]
}
DEPLOY

  parameters {
    "functionAppName" = "${azurerm_function_app.services.name}"
  }

  depends_on = [
    "azurerm_function_app.services"
  ]
}

resource "azurerm_key_vault" "main" {
  name                        = "vaultkv${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  enabled_for_disk_encryption = false
  tenant_id                   = "${var.tenant_id}"
  sku {
    name = "standard"
  } 

  access_policy {
    tenant_id = "${data.azurerm_client_config.current.tenant_id}"
    object_id = "${data.azurerm_client_config.current.service_principal_object_id}"

    secret_permissions = [
      "set"
    ]
  }
  # services access to keyvault
  access_policy {
    tenant_id = "${var.tenant_id}"
    object_id = "${azurerm_function_app.services.identity.0.principal_id}"

    secret_permissions = [
      "get",
    ]
  }  
  # api MSI access to keyvault
  access_policy {
    tenant_id = "${var.tenant_id}"
    object_id = "${module.api.vmss_principal_id}"

    secret_permissions = [
      "get",
    ]
  }  
  # coredb MSI access to keyvault
  access_policy {
    tenant_id = "${var.tenant_id}"
    object_id = "${module.coredb.vmss_principal_id}"

    secret_permissions = [
      "get",
    ]
  }  
}
# secrets
resource "azurerm_key_vault_secret" "storage_account_key" {
  name                = "StorageAccountKey"
  vault_uri           = "${azurerm_key_vault.main.vault_uri}"
  value               = "${azurerm_storage_account.storage.primary_access_key}"
}
resource "azurerm_key_vault_secret" "web_hook_uri" {
  name                = "WebHookUri"
  vault_uri           = "${azurerm_key_vault.main.vault_uri}"
  value               = "none"
}

# create a virtual network
resource "azurerm_virtual_network" "network" {
  name                        = "network-vnet-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  address_space               = ["10.0.0.0/16"]
}
# create host subnet
resource "azurerm_subnet" "api" {
  name                        = "api-sn-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  virtual_network_name        = "${azurerm_virtual_network.network.name}"
  address_prefix              = "10.0.0.0/24"
}
resource "azurerm_subnet" "coredb" {
  name                        = "coredb-sn-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  virtual_network_name        = "${azurerm_virtual_network.network.name}"
  address_prefix              = "10.0.1.0/24"
}
resource "azurerm_subnet" "consul" {
  name                        = "consul-sn-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  virtual_network_name        = "${azurerm_virtual_network.network.name}"
  address_prefix              = "10.0.2.0/24"
}
# create jumpbox subnet
resource "azurerm_subnet" "jumpbox" {
  name                        = "jumpbox-sn-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  virtual_network_name        = "${azurerm_virtual_network.network.name}"
  address_prefix              = "10.0.3.0/24"
}

module "jumpbox" {
  source                    = "modules/jumpbox"
  version                   = "0.0.1"
  unique                    = "${var.unique}"
  resource_group            = "${azurerm_resource_group.main.name}"
  location                  = "${azurerm_resource_group.main.location}"
  subscription_id           = "${var.subscription_id}"
  tenant_id                 = "${var.tenant_id}"
  client_id                 = "${var.client_id}"
  client_secret             = "${var.client_secret}"
  boot_storage_account_uri  = "${var.boot_storage_account_uri}"
  boot_storage_account_name = "${var.boot_storage_account_name}"
  boot_storage_account_key  = "${var.boot_storage_account_key}"
  boot_storage_account_sas  = "${var.boot_storage_account_sas}"
  subnet_id                 = "${azurerm_subnet.jumpbox.id}"
}

module "api" {
  source                    = "modules/vmss"
  version                   = "1.0.0"
  unique                    = "${var.unique}"
  project_name              = "${var.project_name}"
  resource_group            = "${azurerm_resource_group.main.name}"
  location                  = "${azurerm_resource_group.main.location}"
  subscription_id           = "${var.subscription_id}"
  tenant_id                 = "${var.tenant_id}"
  client_id                 = "${var.client_id}"
  client_secret             = "${var.client_secret}"
  boot_storage_account_uri  = "${var.boot_storage_account_uri}"
  boot_storage_account_name = "${var.boot_storage_account_name}"
  boot_storage_account_key  = "${var.boot_storage_account_key}"
  boot_storage_account_sas  = "${var.boot_storage_account_sas}"
  host_role                 = "api"
  subnet_id                 = "${azurerm_subnet.api.id}"
  analytics_workspace_id    = "${azurerm_log_analytics_workspace.analytics.workspace_id}" 
  analytics_workspace_key   = "${azurerm_log_analytics_workspace.analytics.primary_shared_key}" 
  key_vault_id              = "${local.key_vault_id}"
  custom_image_uri          = "${var.custom_image_uri}"
  storage_account_id        = "${azurerm_storage_account.storage.id}"
  status_topic_id           = "${azurerm_eventgrid_topic.status.id}"
  load_balanced             = "true"
  health_path               = "/"
  health_port               = "8001"  
}

module "coredb" {
  source                    = "modules/vmss"
  version                   = "1.0.0"
  unique                    = "${var.unique}"
  project_name              = "${var.project_name}"
  resource_group            = "${azurerm_resource_group.main.name}"
  location                  = "${azurerm_resource_group.main.location}"
  subscription_id           = "${var.subscription_id}"
  tenant_id                 = "${var.tenant_id}"
  client_id                 = "${var.client_id}"
  client_secret             = "${var.client_secret}"
  boot_storage_account_uri  = "${var.boot_storage_account_uri}"
  boot_storage_account_name = "${var.boot_storage_account_name}"
  boot_storage_account_key  = "${var.boot_storage_account_key}"
  boot_storage_account_sas  = "${var.boot_storage_account_sas}"
  host_role                 = "coredb"
  subnet_id                 = "${azurerm_subnet.coredb.id}"
  analytics_workspace_id    = "${azurerm_log_analytics_workspace.analytics.workspace_id}" 
  analytics_workspace_key   = "${azurerm_log_analytics_workspace.analytics.primary_shared_key}" 
  key_vault_id              = "${local.key_vault_id}"
  custom_image_uri          = "${var.custom_image_uri}"
  storage_account_id        = "${azurerm_storage_account.storage.id}"
  status_topic_id           = "${azurerm_eventgrid_topic.status.id}"
  load_balanced             = "true"
  health_path               = "/health"
  health_port               = "8080"  
}

module "consul" {
  source                    = "modules/consul"
  version                   = "1.0.0"
  unique                    = "${var.unique}"
  project_name              = "${var.project_name}"
  resource_group            = "${azurerm_resource_group.main.name}"
  location                  = "${azurerm_resource_group.main.location}"
  subscription_id           = "${var.subscription_id}"
  tenant_id                 = "${var.tenant_id}"
  client_id                 = "${var.client_id}"
  client_secret             = "${var.client_secret}"
  boot_storage_account_uri  = "${var.boot_storage_account_uri}"
  boot_storage_account_name = "${var.boot_storage_account_name}"
  boot_storage_account_key  = "${var.boot_storage_account_key}"
  boot_storage_account_sas  = "${var.boot_storage_account_sas}"
  subnet_id                 = "${azurerm_subnet.consul.id}"
  analytics_workspace_id    = "${azurerm_log_analytics_workspace.analytics.workspace_id}" 
  analytics_workspace_key   = "${azurerm_log_analytics_workspace.analytics.primary_shared_key}"
  consul_tenant_id          = "${var.consul_tenant_id}"
  consul_client_id          = "${var.consul_client_id}"
  consul_client_key         = "${var.consul_client_key}"
}

output "services_id" {
  value = "${azurerm_function_app.services.id}"
}
output "services_principal_id" {
  value = "${azurerm_function_app.services.identity.0.principal_id}"
}
output "storage_account_id" {
  value = "${azurerm_storage_account.storage.id}"
}
output "key_vault_id" {
  value = "${azurerm_key_vault.main.id}"
}
output "key_vault_uri" {
  value = "${azurerm_key_vault.main.vault_uri}"
}
output "status_topic_id" {
  value = "${azurerm_eventgrid_topic.status.id}"
}
output "api_vmss_id" {
  value = "${module.api.vmss_id}"
}
output "api_vmss_principal_id" {
  value = "${module.api.vmss_principal_id}"
}
output "api_vmss_autoscale_id" {
  value = "${module.api.vmss_autoscale_id}"
}
output "coredb_vmss_id" {
  value = "${module.coredb.vmss_id}"
}
output "coredb_vmss_principal_id" {
  value = "${module.coredb.vmss_principal_id}"
}
output "coredb_vmss_autoscale_id" {
  value = "${module.coredb.vmss_autoscale_id}"
}
output "consul_vmss_id" {
  value = "${module.consul.vmss_id}"
}
