data "azurerm_resource_group" "rg"{
    name     = "rg-ethan-vm-2023"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "ethanNetworkSecurityGroup"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  # security_rule {
  #   name                       = "SSH"
  #   priority                   = 1001
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "3389"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }
}

data "azurerm_subnet" "my_terraform_subnet" {
  name                 = "ethan-sbn01"
  virtual_network_name = "ethan-vnet"
  resource_group_name  = "rg-infrarg-lz-2023"
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "ethanWinNIC"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = data.azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

#Create KeyVault VM password
resource "random_password" "vmpassword" {
  length = 20
  special = true
}

data "azurerm_key_vault" "key_vault" {
  name                = "ethan-kv-adm"
  resource_group_name = "rg-infrarg-lz-2023"
}

# Push SSH key into Keyvault secret
resource "azurerm_key_vault_secret" "my_terraform_vmpassword" {
  name         = "ethanwinpassword"
  value        = sensitive(random_password.vmpassword.result)
  key_vault_id = data.azurerm_key_vault.key_vault.id
  content_type = "text/plain"
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "my_terraform_vm" {
  name                  = "ethanwindowsvm"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_F2"

  os_disk {
    name                 = "ethanWinOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  computer_name       = "ethanwindowsvm"
  admin_username      = "adminuser"
  admin_password      = azurerm_key_vault_secret.my_terraform_vmpassword.value
}
