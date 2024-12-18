locals {
  resource_group_name      = "rg_cftc"
  location                 = "East US"
  virtual_network          = {
    name = "cftc_vnet"
    address_space = "10.1.0.0/16"
  }
  vmUN = "cftcadmin"
  vmPwd = "cftconAzur3"
   
}