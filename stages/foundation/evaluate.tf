# Stage: foundation, part 3. Hands the catalogue, the facts and the intent values to the
# generic evaluation. Nothing about individual controls is decided in this stage's HCL.

locals {
  catalogue = yamldecode(file("${path.module}/../../policy/foundation.yaml"))
  now       = plantimestamp()
  # Values a requirement may reference through value_from: the intent's foundation block and
  # a few derived from policy files (so a catalogue entry never repeats what a standard says).
  intent = merge(
    { for k, v in var.foundation : "foundation.${k}" => v },
    {
      "policy.role_names"       = values(local.role_names)
      "policy.scheme_names"     = [for s in local.standards : s.jira.scheme_name]
      "policy.scheme_grants"    = flatten([for s in local.standards : [for role, perms in s.jira.role_permissions : [for p in perms : "${s.jira.scheme_name}|${p}|${local.role_names[role]}"]]])
      "policy.space_role_names" = distinct(flatten([for s in local.standards : values(s.confluence.space_roles)]))
      "policy.admin_accounts"   = [for a in local.identities.accounts : a.id]
      "policy.permitted_realms" = lookup(local.rules.permitted_realms, var.env, [])
    },
    local.treatment_intent, # treatment.tf
  )
}

module "evaluation" {
  source    = "../../modules/control_evaluation"
  catalogue = local.catalogue
  facts     = local.facts
  intent    = local.intent
  products  = ["jira", "confluence", "treatment"]
  now       = local.now
}

locals {
  verdict  = module.evaluation.verdict
  blocking = module.evaluation.blocking
  findings = module.evaluation.findings
  ready    = module.evaluation.ready
}
