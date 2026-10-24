# Stage: foundation, part 0. What the engine provisions from policy (provision: engine).
# Everything created here is read back in observe.tf and judged in evaluate.tf like any other
# fact; an apply is never taken as proof. Roles are site-wide, one per role key across all
# standards; one permission scheme per standard grants to those roles.

locals {
  standard_files = fileset("${path.module}/../../policy/standards", "*.yaml")
  standards      = { for f in local.standard_files : trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/../../policy/standards/${f}")) }
  role_keys      = distinct(flatten([for s in local.standards : s.roles]))
  role_names     = { for r in local.role_keys : r => replace(local.rules.role_name_template, "{role}", r) }
  identities     = yamldecode(file("${path.module}/../../policy/identities.yaml"))
}

module "role" {
  for_each  = local.role_names
  source    = "../../modules/jira_project_role"
  providers = { restapi = restapi.jira }

  name        = each.value
  description = "Platform role '${each.key}'; bound to groups per asset. Managed by platform automation."
}

module "scheme" {
  for_each  = local.standards
  source    = "../../modules/jira_permission_scheme"
  providers = { restapi = restapi.jira }

  name             = each.value.jira.scheme_name
  description      = "Standard ${each.key} | grants to platform roles | managed by platform automation"
  role_permissions = each.value.jira.role_permissions
  role_ids         = { for r, m in module.role : r => m.id }
}

output "role_ids" {
  description = "role key => site-wide Jira project role id; admit binds groups to these."
  value       = { for r, m in module.role : r => m.id }
}
output "scheme_ids" {
  description = "standard id => permission scheme id; admit attaches projects to these."
  value       = { for s, m in module.scheme : s => m.id }
}
