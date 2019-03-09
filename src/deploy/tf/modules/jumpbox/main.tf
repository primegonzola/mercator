variable "unique" {
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
variable "custom_image_uri" {
  type = "string"
}

resource "azurerm_image" "jumpbox" {
  name                  = "jumpbox-img-${var.unique}"
  resource_group_name   = "${var.resource_group}"
  location              = "${var.location}"
  os_disk {
    os_type               = "Linux"
    os_state              = "Generalized"
    blob_uri              = "${var.custom_image_uri}"
    caching               = "ReadWrite"
  }
}

resource "azurerm_public_ip" "jumpbox" {
  name                            = "jumpbox-ip-${var.unique}"
  resource_group_name             = "${var.resource_group}"
  location                        = "${var.location}"
  public_ip_address_allocation    = "dynamic"
  domain_name_label               = "jumpbox-ip-${var.unique}"
}

resource "azurerm_network_security_group" "jumbox" {
  name                        = "jumpbox-nsg-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"

  security_rule {
    name                        = "default_allow_ssh_name"
    protocol                    = "TCP"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    access                      = "Allow"
    priority                    = "1000"
    direction                   = "Inbound"
  }
}
resource "azurerm_network_interface" "jumpbox" {
  name                        = "jumpbox-nic-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  network_security_group_id   = "${azurerm_network_security_group.jumbox.id}"
  ip_configuration {
    name                          = "jumpbox-ipc-${var.unique}"
    subnet_id                     = "${var.subnet_id}"
    public_ip_address_id          = "${azurerm_public_ip.jumpbox.id}"
    private_ip_address_allocation = "dynamic"
  }
}

# create a jumpbox
resource "azurerm_virtual_machine" "main" {
  name                        = "jumpbox-vm-${var.unique}"
  resource_group_name         = "${var.resource_group}"
  location                    = "${var.location}"
  network_interface_ids       = ["${azurerm_network_interface.jumpbox.id}"]
  vm_size                     = "Standard_F1"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true
  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    id  = "${azurerm_image.jumpbox.id}"
  }
  storage_os_disk {
    name              = "jumpbox-dsk-${var.unique}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name     = "jumpbox-vm-${var.unique}"
    admin_username    = "mercator"
    admin_password    = "Dummy2PassWord!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}
