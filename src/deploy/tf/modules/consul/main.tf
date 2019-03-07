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

locals {
  vmss_name   = "consul-vmss-nlb-${var.unique}"
  vmss_id     = "${format("/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Compute/virtualMachineScaleSets/%s", var.subscription_id, var.resource_group, local.vmss_name)}"
}

locals {
  file_init_uri = "${format("%sbootstrap/consul-init.sh%s", var.boot_storage_account_uri, var.boot_storage_account_sas)}"
}

resource "azurerm_virtual_machine_scale_set" "consul" {
  name                    = "${local.vmss_name}"
  resource_group_name     = "${var.resource_group}"
  location                = "${var.location}"
  upgrade_policy_mode     = "Automatic",

  sku {
      name                = "Standard_F2"
      tier                = "Standard"
      capacity            = 3
  }

  identity {
    type    = "SystemAssigned"
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "consul-vm-"
    admin_username       = "mercator"
    admin_password       = "Dummy2PassWord!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name                          = "consul-np-${var.unique}"
    primary                       = true
    accelerated_networking        = true
    ip_configuration {
      name                        = "IPConfiguration"
      subnet_id                   = "${var.subnet_id}"
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
        "fileUris": [ "${local.file_init_uri}" ],
        "commandToExecute": "./consul-init.sh \"${var.project_name}\""
    }
SETTINGS
  }
}
output "vmss_id" {
  value = "${local.vmss_id}"
}
output "vmss_principal_id" {
  value = "${azurerm_virtual_machine_scale_set.consul.identity.0.principal_id}"
}
