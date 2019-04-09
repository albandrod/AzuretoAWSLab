# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  # version = "=1.22.0"
}
# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "rgNetworking"
  location = "West US"
}
# Create a Hub virtual network within the resource group
resource "azurerm_virtual_network" "vnethub" {
  name                = "WUS-HUB-VNET"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["10.0.0.0/22"]
}
# Create a virtual network GatewaySubnet within the resource group
resource "azurerm_subnet" "gwsubnet" {
  name                 = "GatewaySubnet"
  virtual_network_name = "${azurerm_virtual_network.vnethub.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "10.0.0.0/24"
}
# Create a virtual network AzureFirewall within the resource group
resource "azurerm_subnet" "fwsubnet" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = "${azurerm_virtual_network.vnethub.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "10.0.1.0/24"
}
# Create a virtual network SharedServicesSubnet within the resource group
resource "azurerm_subnet" "sssubnet" {
  name                 = "SharedServices"
  virtual_network_name = "${azurerm_virtual_network.vnethub.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "10.0.2.0/24"
}

# Create a Spoke virtual network within the resource group
resource "azurerm_virtual_network" "vnetspoke" {
  name                = "WUS-SPOKE-VNET"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["10.0.4.0/22"]
}
# Create a virtual network DataSubnet within the resource group
resource "azurerm_subnet" "datasubnet" {
  name                 = "DATA"
  virtual_network_name = "${azurerm_virtual_network.vnetspoke.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "10.0.5.0/24"
}
# Create a virtual network AppSubnet within the resource group
resource "azurerm_subnet" "appsubnet" {
  name                 = "APP"
  virtual_network_name = "${azurerm_virtual_network.vnetspoke.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "10.0.6.0/24"
}
# Create a virtual network WebSubnet within the resource group
resource "azurerm_subnet" "websubnet" {
  name                 = "WEB"
  virtual_network_name = "${azurerm_virtual_network.vnetspoke.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "10.0.7.0/24"
}

# Create a Public IP Address for Gateway within the resource group
resource "azurerm_public_ip" "gwpip" {
  name                = "WUS-GW-PIP"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  allocation_method   = "Dynamic"

}

output "azgwpip" {
  value = "${azurerm_public_ip.gwpip.ip_address}"
}

# Create a virtual network Gateway within the resource group
resource "azurerm_virtual_network_gateway" "azgw" {
  name                = "WUS-GATEWAY"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  ip_configuration {
    subnet_id           = "${azurerm_subnet.gwsubnet.id}"
    public_ip_address_id = "${azurerm_public_ip.gwpip.id}"
  }
  sku                  = "VpnGw1"
  type                 = "VPN"
  vpn_type             = "RouteBased"
}

# Create a local network Gateway pointing to AWS VPC VGW within the resource group
resource "azurerm_local_network_gateway" "awsvpc" {
  name                = "AWS-VPC-VGW"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  gateway_address     = "${aws_vpn_connection.main.tunnel1_address}"
  address_space       = ["192.168.0.0/16"]

  depends_on = ["aws_vpn_connection.main"]
}

resource "azurerm_local_network_gateway" "awsvpc2" {
  name                = "AWS-VPC-VGW"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  gateway_address     = "${aws_vpn_connection.main.tunnel2_address}"
  address_space       = ["192.168.0.0/16"]

  depends_on = ["aws_vpn_connection.main"]
}

# Azure to AWS S2S VPN Connection
resource "azurerm_virtual_network_gateway_connection" "azure2aws" {
  name                = "Azure2AWS"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  type                       = "IPsec"
  virtual_network_gateway_id = "${azurerm_virtual_network_gateway.azgw.id}"
  local_network_gateway_id   = "${azurerm_local_network_gateway.awsvpc.id}"

  shared_key = "${aws_vpn_connection.main.tunnel1_preshared_key}"

  depends_on = ["aws_vpn_connection.main"]
}

# Setup peerings between Hub and Spoke
resource "azurerm_virtual_network_peering" "hubtospoke" {
  name                         = "HUB-to-Spoke"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.vnethub.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.vnetspoke.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true

  depends_on = ["azurerm_virtual_network_gateway_connection.azure2aws"]
}

# Setup peerings between Spoke and Hub
resource "azurerm_virtual_network_peering" "spoketohub" {
  name                         = "Spoke-to-Hub"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  virtual_network_name         = "${azurerm_virtual_network.vnetspoke.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.vnethub.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true

  depends_on = ["azurerm_virtual_network_peering.hubtospoke"]
}

# Create a resource group
resource "azurerm_resource_group" "rgvm" {
  name     = "rgVMs"
  location = "West US"
}

# Azure VM PIP
resource "azurerm_public_ip" "azvmpip" {
  name                = "AzureVM-pip"
  location            = "${azurerm_resource_group.rgvm.location}"
  resource_group_name = "${azurerm_resource_group.rgvm.name}"
  allocation_method   = "Dynamic"
}

# Azure VM Nic
resource "azurerm_network_interface" "aznicvm" {
  name                = "AzureVM-nic"
  location            = "${azurerm_resource_group.rgvm.location}"
  resource_group_name = "${azurerm_resource_group.rgvm.name}"

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = "${azurerm_subnet.websubnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.azvmpip.id}"
  }
}

resource "azurerm_virtual_machine" "azvm" {
  name                  = "AzureVM"
  location              = "${azurerm_resource_group.rgvm.location}"
  resource_group_name   = "${azurerm_resource_group.rgvm.name}"
  network_interface_ids = ["${azurerm_network_interface.aznicvm.id}"]
  vm_size               = "Standard_F2"

  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "AzureVM-OSDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "AzureVM"
    admin_username = "${var.vmuser}"
    admin_password = "${var.vmpass}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}