# Stage: conform, part 3. Every instance is judged by the same generic evaluation the foundation
# uses, against the controls of its kind and the values of its standard. The result per instance
# is a verdict per control and the rung policy assigns to each failure.

locals {
  now = plantimestamp()
  instances = merge(
    { for k, _ in local.projects : "jira:${k}" => { kind = "jira", key = k, standard = local.project_std[k], facts = local.project_facts[k] } },
    { for k, _ in local.spaces : "confluence:${k}" => { kind = "confluence", key = k, standard = local.space_std[k], facts = local.space_facts[k] } },
  )
  # Values a requirement may reference through value_from, per instance.
  intent = { for id, i in local.instances : id => {
    "standard.scheme_id"               = tostring(try(local.contract.standards[i.standard].scheme_id, ""))
    "standard.space_required_roles"    = [try(local.standards[i.standard].confluence.space_roles.admin, "Admin")]
    "standard.lifecycle.inactive_days" = try(local.standards[i.standard].lifecycle.inactive_days, null)
    "tenant.group_pattern"             = var.tenant.group_pattern
  } }
  catalogue = { for kind in ["jira", "confluence"] : kind => {
    version  = local.policy.version
    controls = [for c in local.policy.controls : merge(c, { mandatory = false }) if contains(c.depends, kind)]
  } }
}

module "evaluation" {
  for_each  = local.instances
  source    = "../../modules/control_evaluation"
  catalogue = local.catalogue[each.value.kind]
  facts     = each.value.facts
  intent    = local.intent[each.key]
  products  = [each.value.kind]
  now       = local.now
}

locals {
  rung    = { for c in local.policy.controls : c.id => c.action }
  failing = { for id, m in module.evaluation : id => [for cid, v in m.verdict : cid if !contains(["pass", "attested", "not_applicable"], v)] }
  verdicts = { for id, i in local.instances : id => {
    kind     = i.kind
    key      = i.key
    standard = i.standard
    verdict  = module.evaluation[id].verdict
    actions = { for cid in local.failing[id] : cid => {
      rung      = local.rung[cid]
      performed = contains(local.policy.enabled_actions, local.rung[cid]) ? local.rung[cid] : "report"
    } }
  } }
  findings = flatten([for id, v in local.verdicts : [for cid, a in v.actions : "${id} ${cid}=${v.verdict[cid]} -> ${a.rung}${a.performed == a.rung ? "" : " (planned; performed: report)"}"]])
}

resource "terraform_data" "policy_is_consistent" {
  lifecycle {
    precondition {
      condition     = alltrue([for c in local.policy.controls : contains(["report", "flag", "restrict", "archive"], c.action)])
      error_message = "policy/conformance.yaml: action must be report, flag, restrict or archive (delete is not a rung)."
    }
    precondition {
      condition     = alltrue([for a in local.policy.enabled_actions : contains(["report"], a)])
      error_message = "Only the report rung has an executor yet; flag, restrict and archive arrive in later phases."
    }
    precondition {
      condition     = contains(keys(local.standards), local.policy.fallback_standard)
      error_message = "policy/conformance.yaml: fallback_standard must be a file in policy/standards."
    }
  }
}
