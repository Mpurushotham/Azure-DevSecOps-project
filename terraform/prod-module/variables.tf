variable "prefix" {
  type = string
  description = "name prefix"
}
variable "location" {
  type = string
  default = "westeurope"
}
variable "subscription_id" {
  type = string
}
variable "tenant_id" {
  type = string
}
variable "aks_admins" {
  type = list(string)
  default = []
  description = "List of AAD users or group object IDs who will be AKS admins (needs AAD admin consent)"
}
