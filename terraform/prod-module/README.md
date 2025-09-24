Production Terraform module skeleton for Azure hardened infra (VNet, Private AKS, Private ACR, Log Analytics, Key Vault)

IMPORTANT NOTES:
- Azure AD integration for AKS requires tenant admin consent for Pod Identity or AAD integration.
- This module is a starting point. Review networking CIDRs, NSGs, private endpoints, and access policies before using in production.
- Replace placeholders and add backend/state management (remote state, locking).

Usage example (call module with your values):

module "prod_platform" {
  source            = "./terraform/prod-module"
  prefix            = "acme"
  location          = "westeurope"
  subscription_id   = "<SUBSCRIPTION_ID>"
  tenant_id         = "<TENANT_ID>"
  aks_admins         = ["<ADMIN_UPN_OR_OBJECTID>"]
}
