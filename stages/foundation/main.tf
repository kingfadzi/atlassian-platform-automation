# Stage: foundation, part 5. Readiness is dependency-specific: a failing mandatory control
# blocks the products that depend on it and nothing else. stages/admit reads these outputs
# through terraform_remote_state and refuses to plan Jira or Confluence assets that are not ready.

locals {
  by_id_prov = { for c in local.catalogue.controls : c.id => c }
}

check "mandatory_controls" {
  assert {
    condition     = length(local.blocking) == 0
    error_message = "Mandatory foundation controls not satisfied: ${join(", ", [for id, dep in local.blocking : "${id} (${local.verdict[id]}; blocks ${join("+", dep)})"])}."
  }
}

check "report_controls" {
  assert {
    condition     = length(local.findings) == 0
    error_message = "Foundation findings (reported, not blocking): ${join(", ", [for id, s in local.findings : "${id}=${s}"])}."
  }
}

output "ready" {
  description = "Per-product readiness consumed by stages/admit."
  value       = local.ready
}
output "controls" { value = local.verdict }
output "entitlement" {
  description = "What the tenant's plans allow, for reading runbook findings honestly."
  value       = { jira_application_plans = local.facts.jira_application_plans.value, confluence_seat_capacity = local.facts.confluence_seat_capacity.value }
}
output "provision" {
  description = "Who makes each control true: engine, runbook or external (from policy)."
  value       = { for id, c in local.by_id_prov : id => c.provision }
}
output "blocking" { value = local.blocking }
output "findings" { value = local.findings }
# Outputs must be stable between plans; volatile observations (event timestamps) stay out.
output "details" {
  description = "Stable fact values useful to a reviewer (volatile ones such as timestamps are excluded)."
  value = {
    public_grants   = local.facts.scheme_grants_to_anyone.value
    sitewide_browse = local.facts.scheme_browse_for_all_licensed.value
    domains         = local.facts.verified_domains.value
    # null, not an empty list: no resolver declared means DNS was never read, which is not the
    # same as every record resolving.
    domains_missing_record = local.facts.domains_missing_verification_record.known ? local.facts.domains_missing_verification_record.value : null
    confluence_retention   = local.facts.confluence_audit_retention_days.value
    default_access_groups  = local.facts.default_access_groups.value
    asset_workflow_gaps    = local.facts.asset_workflow_gaps.value
    disallowed_permissions = local.facts.accounts_holding_disallowed_permissions.value
  }
}
output "policy_version" {
  description = "Catalogue version the readiness was evaluated under."
  value       = tostring(local.catalogue.version)
}
output "evaluated_on" {
  description = "Day of this evaluation; admit treats evaluations older than the policy window as stale."
  value       = formatdate("YYYY-MM-DD", local.now)
}
