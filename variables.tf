variable "vm_count" {
  description = "Number of lab VMs to create. Change this to scale the lab up or down."
  type        = number
  default     = 1
}

variable "admin_password" {
  description = "Administrator password for all lab VMs"
  type        = string
  sensitive   = true
}
