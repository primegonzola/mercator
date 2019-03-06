variable "unique" {
  type = "string"
}
variable "project_name" {
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
variable "subnet_id" {
  type = "string"
}
variable "analytics_workspace_id" {
  type = "string"
}
variable "analytics_workspace_key" {
  type = "string"
}
variable "storage_account_id" {
  type = "string"
}
variable "status_topic_id" {
  type = "string"
}
variable "custom_image_uri" {
  type = "string"
}
variable "key_vault_id" {
  type = "string"
}
variable "host_role" {
  type = "string"
}
variable "load_balanced" {
  type = "string"
  default = "false"
}

# variable "lb_bep_id" {
#   type = "string"
#   default = null
# }

variable "health_path" {
  type = "string"
  default = "/"
}

variable "health_port" {
  type = "string"
  default = "80"
}


# host
resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  number  = false
}
resource "azurerm_public_ip" "host" {
  name                            = "${var.host_role}-ip-${var.unique}"
  resource_group_name             = "${var.resource_group}"
  location                        = "${var.location}"
  public_ip_address_allocation    = "static"
  domain_name_label               = "${random_string.fqdn.result}"
  sku                             = "Standard"  
}
resource "azurerm_lb" "host" {
  name                            = "${var.host_role}-lb-${var.unique}"
  resource_group_name             = "${var.resource_group}"
  location                        = "${var.location}"
  sku                             = "Standard"

  frontend_ip_configuration {
    name                  = "PublicIPAddress"    
    public_ip_address_id  = "${azurerm_public_ip.host.id}"
 }
}
resource "azurerm_lb_backend_address_pool" "host" {
  resource_group_name              = "${var.resource_group}"
  loadbalancer_id                  = "${azurerm_lb.host.id}"
  name                             = "BackEndAddressPool"
}
resource "azurerm_lb_probe" "host" {
  resource_group_name              = "${var.resource_group}"
  loadbalancer_id                  = "${azurerm_lb.host.id}"
  protocol                         = "http"
  name                             = "http-health-probe"
  request_path                     = "${var.health_path}"
  port                             = "${var.health_port}"      
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = "${var.resource_group}"
  loadbalancer_id                = "${azurerm_lb.host.id}"
  name                           = "https"
  protocol                       = "Tcp"
  frontend_port                  = "443"
  backend_port                   = "443"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.host.id}"
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = "${azurerm_lb_probe.host.id}"
}

locals {
  vmss_name_slb = "${var.host_role}-vmss-slb-${var.unique}"
  vmss_name_nlb = "${var.host_role}-vmss-nlb-${var.unique}"
  vmss_name     = "${var.load_balanced == "true" ? local.vmss_name_slb : local.vmss_name_nlb }"
  vmss_id       = "${format("/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Compute/virtualMachineScaleSets/%s", var.subscription_id, var.resource_group, local.vmss_name)}"
}

locals {
  file_download_uri = "${format("%sbootstrap/download.sh%s", var.boot_storage_account_uri, var.boot_storage_account_sas)}"
  file_init_uri = "${format("%sbootstrap/host-init.sh%s", var.boot_storage_account_uri, var.boot_storage_account_sas)}"
}

resource "azurerm_image" "host" {
  name                  = "${var.host_role}-img-${var.unique}"
  resource_group_name   = "${var.resource_group}"
  location              = "${var.location}"
  os_disk {
    os_type               = "Linux"
    os_state              = "Generalized"
    blob_uri              = "${var.custom_image_uri}"
    caching               = "ReadWrite"
  }
}

resource "azurerm_virtual_machine_scale_set" "host" {
  name                            = "${local.vmss_name}"
  resource_group_name             = "${var.resource_group}"
  location                        = "${var.location}"
  upgrade_policy_mode             = "Automatic",
  zones                           = [ "1", "2" , "3"]

  sku {
      name                = "Standard_E4s_v3"
      tier                = "Standard"
      capacity            = 0
  }

  identity {
    type    = "SystemAssigned"
  }
  storage_profile_image_reference {
    id      = "${azurerm_image.host.id}"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name_prefix = "${var.host_role}-vm-"
    admin_username       = "mercator"
    admin_password       = "Dummy2PassWord!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name                        = "${var.host_role}-np-${var.unique}"
    primary                     = true
    accelerated_networking      = true
    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = "${var.subnet_id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.host.id}"]
      primary = true
    }
  }

  extension {
    name                          = "OMSExtension"
    publisher                     = "Microsoft.EnterpriseCloud.Monitoring"
    type                          = "OmsAgentForLinux"
    type_handler_version          = "1.7"
    settings                      = "{\"workspaceId\": \"${var.analytics_workspace_id}\"}"
    protected_settings            = "{\"workspaceKey\": \"${var.analytics_workspace_key}\"}"
  }

  extension {
    name                          = "bootstrapcmd"
    publisher                     = "Microsoft.Azure.Extensions"
    type                          = "CustomScript"
    type_handler_version          = "2.0"
    settings                      = <<SETTINGS
    {
        "fileUris": [ "${local.file_download_uri}", "${local.file_init_uri}" ],
        "commandToExecute": "./host-init.sh \"${var.project_name}\" \"${var.boot_storage_account_name}\" \"${var.boot_storage_account_key}\" \"${var.boot_storage_account_sas}\" \"VirtualMachineScaleSet\" \"${local.vmss_id}\" \"${var.host_role}\" \"${var.status_topic_id}\" \"${var.storage_account_id}\" \"${var.key_vault_id}\""
    }
SETTINGS
  }
}

resource "azurerm_autoscale_setting" "host" {
  name                  = "${var.host_role}-vmss-autoscale-${var.unique}"
  resource_group_name   = "${var.resource_group}"
  location              = "${var.location}"
  target_resource_id    = "${azurerm_virtual_machine_scale_set.host.id}"

  profile {
    name = "Profile1"

    capacity {
      default = 1
      minimum = 1
      maximum = 8
    }
  }
}
output "vmss_id" {
  value = "${local.vmss_id}"
}
output "vmss_principal_id" {
  value = "${azurerm_virtual_machine_scale_set.host.identity.0.principal_id}"
}
output "vmss_autoscale_id" {
  value = "${azurerm_autoscale_setting.host.id}"
}