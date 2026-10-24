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
  conformance    = yamldecode(file("${path.module}/../../policy/conformance.yaml"))
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

# The contract JSM needs to create instances from the templates, and the stamp it must set so
# stages/conform can tell which template an instance belongs to. Written to contracts/<env>.json
# by the pipeline after apply; nothing in it is secret.
output "contract" {
  value = {
    standards = { for id, s in local.standards : id => {
      scheme_id     = module.scheme[id].id
      roles         = { for r in s.roles : r => module.role[r].id }
      project_types = s.jira.project_types
      space_roles   = s.confluence.space_roles
    } }
    group_pattern = var.tenant.group_pattern
    stamp         = local.conformance.stamp
  }
}

resource "terraform_data" "standards_are_versioned" {
  lifecycle {
    precondition {
      condition     = alltrue([for id in keys(local.standards) : can(regex(local.rules.standard_id_pattern, id))])
      error_message = "Every file in policy/standards must be named <id>-v<n>.yaml (policy/intent_rules.yaml)."
    }
  }
}
