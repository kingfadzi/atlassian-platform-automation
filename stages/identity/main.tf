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

# Memberships live here because this is the only stage where the group ids exist. Flattened to
# one resource per (group, account) pair so a single added member plans as a single create.
module "membership" {
  source    = "../../modules/group_membership"
  providers = { restapi = restapi.jira }
  for_each = {
    for pair in flatten([
      for group, ids in var.memberships : [
        for id in ids : { group = group, account_id = id }
      ]
    ]) : "${pair.group}:${pair.account_id}" => pair
  }

  group_id             = module.group[each.value.group].id
  group_name           = each.value.group
  account_id           = each.value.account_id
  site_url             = var.tenant.site_url
  authorization_header = local.site_basic_auth
}

output "group_ids" {
  description = "Atlassian group ids by name, for later stages and the readiness ledger."
  value       = { for name, m in module.group : name => m.id }
}

output "membership_ids" {
  description = "Members placed in managed groups, keyed group:accountId."
  value       = { for k, m in module.membership : k => m.id }
}
