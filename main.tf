# ============================================================
# Terraform — VM de PRÁCTICA (no es servidoraud)
# ------------------------------------------------------------
# crea un grupo de recursos APARTE (rg-terraform-practica) con
# red, firewall, IP pública y una VM Ubuntu pequeña para
# aprender el ciclo completo: init -> plan -> apply -> destroy
#
# terraform SOLO toca lo que él crea y anota en su estado
# (terraform.tfstate). servidoraud vive en otro grupo de
# recursos y no se ve afectado
#
# nunca subir a github archivos como terraform.tfstate, *.tfvars con secretos ni llaves .pem

# ============================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# --- Variables ---
variable "location" {
  description = "Región de Azure (la misma que servidoraud)"
  type        = string
  default     = "northcentralus"
}

variable "resource_group_name" {
  description = "Grupo de recursos de la práctica (separado del real)"
  type        = string
  default     = "rg-terraform-practica"
}

variable "admin_username" {
  description = "Usuario administrador de la VM"
  type        = string
  default     = "azureuser"
}

variable "ruta_llave_publica" {
  description = "Ruta de la llave PÚBLICA SSH para entrar a la VM"
  type        = string
  default     = "~/.ssh/terraform_practica_rsa.pub"
}

# --- Grupo de recursos (la "caja" donde vive todo lo de la práctica) ---
resource "azurerm_resource_group" "practica" {
  name     = var.resource_group_name
  location = var.location
}

# --- red virtual ---
resource "azurerm_virtual_network" "practica" {
  name                = "tfpractica-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.practica.location
  resource_group_name = azurerm_resource_group.practica.name
}

resource "azurerm_subnet" "practica" {
  name                 = "tfpractica-subnet"
  resource_group_name  = azurerm_resource_group.practica.name
  virtual_network_name = azurerm_virtual_network.practica.name
  address_prefixes     = ["10.1.1.0/24"]
}

# --- firewall ---
resource "azurerm_network_security_group" "practica" {
  name                = "tfpractica-nsg"
  location            = azurerm_resource_group.practica.location
  resource_group_name = azurerm_resource_group.practica.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "practica" {
  subnet_id                 = azurerm_subnet.practica.id
  network_security_group_id = azurerm_network_security_group.practica.id
}

# --- la ip publica ---
resource "azurerm_public_ip" "practica" {
  name                = "tfpractica-ip"
  location            = azurerm_resource_group.practica.location
  resource_group_name = azurerm_resource_group.practica.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- tarjeta de red ---
resource "azurerm_network_interface" "practica" {
  name                = "tfpractica-nic"
  location            = azurerm_resource_group.practica.location
  resource_group_name = azurerm_resource_group.practica.name

  ip_configuration {
    name                          = "interna"
    subnet_id                     = azurerm_subnet.practica.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.practica.id
  }
}

# --- vm mismo tamaño que servidoraud ---
resource "azurerm_linux_virtual_machine" "practica" {
  name                = "vm-tfpractica"
  location            = azurerm_resource_group.practica.location
  resource_group_name = azurerm_resource_group.practica.name
  size                = "Standard_B2ats_v2"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.practica.id,
  ]


  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ruta_llave_publica))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# --- salidas del apply ---
output "ip_publica" {
  description = "IP pública de la VM de práctica"
  value       = azurerm_public_ip.practica.ip_address
}

output "comando_ssh" {
  description = "Comando para entrar a la VM de práctica"
  value       = "ssh -i ~/.ssh/terraform_practica ${var.admin_username}@${azurerm_public_ip.practica.ip_address}"
}
