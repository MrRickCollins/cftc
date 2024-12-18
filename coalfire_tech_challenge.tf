terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.13.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  subscription_id = "061145ad-fb32-4f1b-8d91-4f95ac9b5d15"
  tenant_id = "74ea466a-f5e7-4d20-8889-a5e9d914704f"
    client_id = "902bc0e0-2380-4280-85c3-2679763b9f16"
    client_secret = "gTt8Q~~XsOJ3qGqZiwIAlKFQVEiLEQIiPiiSpacM"
    
    features {

    }
  
}

data "azurerm_subnet" "sub1" {
  name                 = "sub1"
  virtual_network_name = "cftc_vnet"
  resource_group_name  = "rg_cftc"

  depends_on = [ azurerm_virtual_network.cftc_vnet ]
}

data "azurerm_subnet" "sub2" {
  name                 = "sub2"
  virtual_network_name = "cftc_vnet"
  resource_group_name  = "rg_cftc"

  depends_on = [ azurerm_virtual_network.cftc_vnet ]
}

data "azurerm_subnet" "sub3" {
  name                 = "sub3"
  virtual_network_name = "cftc_vnet"
  resource_group_name  = "rg_cftc"

  depends_on = [ azurerm_virtual_network.cftc_vnet ]
}

// ***** Resource Group *****
resource "azurerm_resource_group" "rg_cftc" {
  name     = local.resource_group_name
  location = local.location
}

// ***** VNET/Subnets (4) *****
resource "azurerm_virtual_network" "cftc_vnet" {
  name                = "cftc_vnet"
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = [local.virtual_network.address_space]
  
  subnet {
    name             = "sub1"
    address_prefixes = ["10.1.0.0/24"]
    security_group = azurerm_network_security_group.cftc_base_nsg.id
    service_endpoints    = ["Microsoft.Storage"]
  }

  subnet {
    name             = "sub2"
    address_prefixes = ["10.1.1.0/24"]
    service_endpoints    = ["Microsoft.Storage"]
    
  }

   subnet {
    name             = "sub3"
    address_prefixes = ["10.1.2.0/24"]
    service_endpoints    = ["Microsoft.Storage"]
     
  }

  subnet {
    name             = "sub4"
    address_prefixes = ["10.1.3.0/24"]
    service_endpoints    = ["Microsoft.Storage"]
     
  }

depends_on = [ 
    azurerm_resource_group.rg_cftc ]

}

// ***** NSGs *****
resource "azurerm_network_security_group" "cftc_base_nsg" {
  name                = "cftc_base_nsg"
  location            = local.location
  resource_group_name = local.resource_group_name
/// ***** port rule for internal SSH VNET traffic *****
  security_rule {
    name                       = "cftc_SSH_In"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
  
  depends_on = [ azurerm_resource_group.rg_cftc ]
 }

  resource "azurerm_network_security_group" "cftc_alb_nsg" {
  name                = "cftc_alb_nsg"
  location            = local.location
  resource_group_name = local.resource_group_name
/// ***** port rule for internal VNET traffic and ALB *****
  security_rule {
    name                       = "cftc_vnet_In"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
  depends_on = [ azurerm_resource_group.rg_cftc ]
 }

 resource "azurerm_subnet_network_security_group_association" "cftc_alb_nsg_assoc" {
  subnet_id                 = data.azurerm_subnet.sub3.id
  network_security_group_id = azurerm_network_security_group.cftc_alb_nsg.id

  depends_on = [ azurerm_network_security_group.cftc_alb_nsg]
}

// ***** AVSET *****
resource "azurerm_availability_set" "cftc_avset" {
  name                = "cftc_avset"
  location            = local.location
  resource_group_name = local.resource_group_name
  platform_fault_domain_count = 3
  platform_update_domain_count = 3

  depends_on = [ azurerm_resource_group.rg_cftc ]
}

// ***** NICS (2) for Sub1 VMs *****

resource "azurerm_network_interface" "cftcvm1_nic" {
  name                = "cftcvm1_nic"
  resource_group_name = local.resource_group_name
  location            = local.location

  ip_configuration {
    name                          = "cftcvm1_nic_cfg"
    subnet_id                     = data.azurerm_subnet.sub1.id
    private_ip_address_allocation = "Dynamic"
    
  }

   depends_on = [ azurerm_virtual_network.cftc_vnet ]
}

resource "azurerm_network_interface" "cftcvm2_nic" {
  name                = "cftcvm2_nic"
  resource_group_name = local.resource_group_name
  location            = local.location

  ip_configuration {
    name                          = "cftcvm2_nic_cfg"
    subnet_id                     = data.azurerm_subnet.sub1.id
    private_ip_address_allocation = "Dynamic"
    
  }

   depends_on = [ azurerm_virtual_network.cftc_vnet ]
}

// ***** End NICS for Sub1 VMs *****

// ***** VMs (2) Added to AVSET *****
resource "azurerm_linux_virtual_machine" "cftcvm1" {
  name                            = "cftcvm1"
  resource_group_name             = local.resource_group_name
  location                        = local.location
  size                            = "Standard_DS1_v2"
  admin_username                  = local.vmUN
  admin_password                  = local.vmPwd
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.cftcvm1_nic.id,
  ]
  availability_set_id = azurerm_availability_set.cftc_avset.id

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.8"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = "256"
  }

  depends_on = [ 
    azurerm_network_interface.cftcvm1_nic,
    azurerm_availability_set.cftc_avset
   ]
}

resource "azurerm_linux_virtual_machine" "cftcvm2" {
  name                            = "cftcvm2"
  resource_group_name             = local.resource_group_name
  location                        = local.location
  size                            = "Standard_DS1_v2"
  admin_username                  = local.vmUN
  admin_password                  = local.vmPwd
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.cftcvm2_nic.id,
  ]
  availability_set_id = azurerm_availability_set.cftc_avset.id

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.8"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = "256"
  }

  depends_on = [ 
    azurerm_network_interface.cftcvm2_nic,
    azurerm_availability_set.cftc_avset
   ]
}


// ***** NIC for VM3 *****
resource "azurerm_network_interface" "cftcvm3_nic" {
  name                = "cftcvm3_nic"
  resource_group_name = local.resource_group_name
  location            = local.location

  ip_configuration {
    name                          = "cftcvm3_nic_cfg"
    subnet_id                     = data.azurerm_subnet.sub3.id
    private_ip_address_allocation = "Dynamic"
    
  }

   depends_on = [ azurerm_virtual_network.cftc_vnet ]
}

// ***** VM3 *****
resource "azurerm_linux_virtual_machine" "cftcvm3" {
  name                            = "cftcvm3"
  resource_group_name             = local.resource_group_name
  location                        = local.location
  size                            = "Standard_DS1_v2"
  admin_username                  = local.vmUN
  admin_password                  = local.vmPwd
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.cftcvm3_nic.id,
  ]
 
 
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.8"
    version   = "latest"
  }


  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
    //disk_size_gb         = "32"
  }


  depends_on = [ 
    azurerm_network_interface.cftcvm3_nic,
   ]
}

// storage account with service endpoint and secure access from VNET Subnets


resource "azurerm_storage_account" "cftcstorage01" {
  name                     = "cftcstorage01"
  resource_group_name      = local.resource_group_name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  

  network_rules {
    default_action = "Deny"
    virtual_network_subnet_ids =  [
     data.azurerm_subnet.sub1.id,
      data.azurerm_subnet.sub2.id,
      data.azurerm_subnet.sub3.id
    ]
    
  }
depends_on = [ azurerm_virtual_network.cftc_vnet ]  

}

# resource "azurerm_subnet_service_endpoint_storage_policy" "se_policy_storage" {
#   name                = "se_policy_storage"
#   resource_group_name = local.resource_group_name
#   location            = local.location
#   definition {
#     name        = "se1"
#     description = "storage account endpoint 1"
#     service     = "Microsoft.Storage"
#     service_resources = [
#       azurerm_resource_group.rg_cftc.id,
#       azurerm_storage_account.cftcstorage01.id
#     ]
#   }
#   definition {
#     name        = "se2"
#     description = "storage account endpoint 2"
#     service     = "Global"
#     service_resources = [
#       "/services/Azure",
#       "/services/Azure/Batch",
#       "/services/Azure/DataFactory",
#       "/services/Azure/MachineLearning",
#       "/services/Azure/ManagedInstance",
#       "/services/Azure/WebPI",
#     ]
#   }

#   depends_on = [ azurerm_storage_account.cftcstorage01 ]
# }


// Public IP for Load Balancer
resource "azurerm_public_ip" "ALB_Public_IP" {
  name                = "ALB_Public_IP"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"

  depends_on = [ azurerm_resource_group.rg_cftc ]
}

// Load Balancer for VM3
resource "azurerm_lb" "cftc_ALB" {
  name                = "cftc_ALB"
   location            = local.location
  resource_group_name = local.resource_group_name

  frontend_ip_configuration {
    name                 = "ALB_Public_IP_Address"
    public_ip_address_id = azurerm_public_ip.ALB_Public_IP.id
  }

  depends_on = [ azurerm_public_ip.ALB_Public_IP ]
}

// Backend Pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "ALB_Pool01" {
  loadbalancer_id = azurerm_lb.cftc_ALB.id
  name            = "ALB_Pool01"

  depends_on = [azurerm_lb.cftc_ALB ]
}

// Load Balancer Pool Address
resource "azurerm_lb_backend_address_pool_address" "ALB_VM3_Address_Pool" {
  name                    = "ALB_VM3_Address_Pool"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ALB_Pool01.id
  virtual_network_id      = azurerm_virtual_network.cftc_vnet.id
  ip_address              = azurerm_network_interface.cftcvm3_nic.private_ip_address

  depends_on = [ azurerm_lb_backend_address_pool.ALB_Pool01 ]
}

// Load Balancer Health Probe
resource "azurerm_lb_probe" "ALB_Probe01" {
  loadbalancer_id = azurerm_lb.cftc_ALB.id
  name            = "ALB-vm3-ssh-probe"
  port            = 22

  depends_on = [ azurerm_lb.cftc_ALB ]
}

//Bastion Instance Creation with Subnet and Public IP

resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.cftc_vnet.name
  address_prefixes     = ["10.1.168.224/27"]

depends_on = [ azurerm_virtual_network.cftc_vnet ]
}

resource "azurerm_public_ip" "Bastion_IP" {
  name                = "Bastion_IP"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "cftc_Bastion" {
  name                = "cftc_Bastion"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                 = "cftc_Bastion_IP"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.Bastion_IP.id
  }

  depends_on = [ azurerm_subnet.AzureBastionSubnet]
}