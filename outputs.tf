output "bastion_name" {
  value = azurerm_bastion_host.bastion.name
}

output "bastion_public_ip" {
  value = azurerm_public_ip.bastion.ip_address
}

output "vm_names" {
  value = azurerm_windows_virtual_machine.lab[*].name
}

output "vm_private_ips" {
  value = azurerm_network_interface.lab[*].private_ip_address
}
