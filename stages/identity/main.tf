# Stage: identity. The managed directory groups. One resource per group, created once and
# never deleted or renamed by automation.

module "group" {
  source    = "../../modules/directory_group"
  for_each  = var.groups
  providers = { restapi = restapi.admin }

  org_id       = var.tenant.org_id
  directory_id = var.tenant.directory_id
  name         = each.key
  description  = each.value
  scope_regex  = var.tenant.scope_regex
}

output "group_ids" {
  description = "Atlassian group ids by name, for later stages and the readiness ledger."
  value       = { for name, m in module.group : name => m.id }
}
