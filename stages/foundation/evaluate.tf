# Stage: foundation, part 2. Turns observations and attestations into one state per control:
# pass | fail | attested | unknown | not_applicable. unknown means the API could not be read
# (entitlement, permission, outage); for a mandatory control that blocks like a failure.

locals {
  catalogue      = yamldecode(file("${path.module}/../../policy/foundation.yaml"))
  attestations   = try(yamldecode(file("${var.runtime_dir}/attestations.yaml")).records, [])
  now            = plantimestamp()
  freshness      = "-${local.catalogue.audit_freshness_days * 24}h"
  attest_win     = "${local.catalogue.attestation_window_days * 24}h"
  retention_days = { DAYS = 1, WEEKS = 7, MONTHS = 30, YEARS = 365, DECADES = 3650, FOREVER = 36500 }

  body = { for k, d in {
    anonymous_jira             = data.http.anonymous_jira, anonymous_confluence = data.http.anonymous_confluence,
    permission_schemes         = data.http.permission_schemes, org_events = data.http.org_events,
    application_roles          = data.http.application_roles, domains = data.http.domains, policies = data.http.policies,
    confluence_audit_retention = data.http.confluence_audit_retention, announcement_banner = data.http.announcement_banner,
    workspaces                 = data.http.workspaces,
  } : k => { status = d.status_code, json = try(jsondecode(d.response_body), {}) } }

  schemes       = try(local.body.permission_schemes.json.permissionSchemes, [])
  public_grants = flatten([for s in local.schemes : [for p in try(s.permissions, []) : "${s.name}:${p.permission}" if try(p.holder.type, "") == "anyone"]])
  sitewide      = [for s in local.schemes : s.name if anytrue([for p in try(s.permissions, []) : p.permission == "BROWSE_PROJECTS" && try(p.holder.type, "") == "applicationRole"])]
  latest_event  = try(local.body.org_events.json.data[0].attributes.time, null)
  domains_seen  = try([for d in local.body.domains.json.data : d.attributes.name], [])
  residency     = try([for p in local.body.policies.json.data : p if p.attributes.type == "data-residency" && p.attributes.status == "enabled"], [])
  retention     = try(local.body.confluence_audit_retention.json, null)
  retention_ok  = local.retention != null && try(local.retention.number * local.retention_days[local.retention.units], 0) >= local.catalogue.confluence_audit_retention_min_days
  role_groups   = try(flatten([for r in local.body.application_roles.json : r.defaultGroups]), [])
  banner        = try(local.body.announcement_banner.json, null)

  # Any refusal satisfies an anonymous probe, not only 401: Confluence answers 404 to an
  # unauthenticated space list and Jira can answer 403. stages/release uses the same set.
  refusals = [401, 403, 404]

  # Entitlement is observable; trial status is not exposed by the workspaces payload, so the
  # lab's Free/trial position is carried as a dated exception in runtime/<env>/exceptions.yaml.
  # Jira is judged on the best plan across the jira* instances, because the bare "jira"
  # workspace is the administration shell and always reports no plan of its own.
  plan_rank    = { None = 0, Free = 1, Standard = 2, Premium = 3, Enterprise = 4 }
  instances    = try(local.body.workspaces.json.data, [])
  entitlements = { for w in local.instances : w.attributes.typeKey => try(w.relationships.entitlement[0].attributes.plan, "None") }
  jira_ranks   = concat([0], [for k, p in local.entitlements : lookup(local.plan_rank, p, 0) if startswith(k, "jira")])
  product_rank = {
    jira       = max(local.jira_ranks...)
    confluence = lookup(local.plan_rank, lookup(local.entitlements, "confluence", "None"), 0)
  }
  min_rank = lookup(local.plan_rank, var.foundation.minimum_plan, 2)

  observed = {
    anonymous_jira_closed           = contains(local.refusals, local.body.anonymous_jira.status) ? "pass" : (local.body.anonymous_jira.status != 200 ? "unknown" : (try(local.body.anonymous_jira.json.total, 1) == 0 ? "pass" : "fail"))
    anonymous_confluence_closed     = contains(local.refusals, local.body.anonymous_confluence.status) ? "pass" : (local.body.anonymous_confluence.status != 200 ? "unknown" : (length(try(local.body.anonymous_confluence.json.results, [1])) == 0 ? "pass" : "fail"))
    jira_restriction_entitled       = local.body.workspaces.status != 200 ? "unknown" : (local.product_rank.jira >= local.min_rank ? "pass" : "fail")
    confluence_restriction_entitled = local.body.workspaces.status != 200 ? "unknown" : (local.product_rank.confluence >= local.min_rank ? "pass" : "fail")
    no_public_scheme_grants         = local.body.permission_schemes.status != 200 ? "unknown" : (length(local.public_grants) == 0 ? "pass" : "fail")
    audit_collection_live           = local.body.org_events.status != 200 ? "unknown" : (local.latest_event != null && timecmp(local.latest_event, timeadd(local.now, local.freshness)) >= 0 ? "pass" : "fail")
    no_sitewide_browse_grants       = local.body.permission_schemes.status != 200 ? "unknown" : (length(local.sitewide) == 0 ? "pass" : "fail")
    product_access_by_group         = local.body.application_roles.status != 200 ? "unknown" : (length(var.foundation.product_access_groups) == 0 ? "pass" : (length(setsubtract(local.role_groups, var.foundation.product_access_groups)) == 0 ? "pass" : "fail"))
    verified_domains_known          = local.body.domains.status != 200 ? "unknown" : (length(var.foundation.domains) == 0 || length(setsubtract(var.foundation.domains, local.domains_seen)) == 0 ? "pass" : "fail")
    org_policies_enabled            = local.body.policies.status != 200 ? "unknown" : (length(local.residency) > 0 ? "pass" : "fail")
    confluence_audit_retention      = local.body.confluence_audit_retention.status != 200 ? "unknown" : (local.retention_ok ? "pass" : "fail")
    announcement_banner             = local.body.announcement_banner.status != 200 ? "unknown" : (local.banner != null && try(local.banner.isEnabled, false) && strcontains(try(local.banner.message, ""), var.foundation.banner_contains) ? "pass" : "fail")
  }

  attested = { for r in local.attestations : r.id => timecmp(timeadd(r.recorded, local.attest_win), local.now) >= 0 if r.kind == "attestation" }

  controls = { for c in local.catalogue.controls : c.id =>
    try(c.lab, "") == "not_applicable" ? "not_applicable" :
    c.method == "attest" ? (lookup(local.attested, c.id, false) ? "attested" : "fail") :
    lookup(local.observed, c.id, "unknown")
  }
  ok_states = ["pass", "attested", "not_applicable"]
  blocking  = { for c in local.catalogue.controls : c.id => c.depends if c.mandatory && !contains(local.ok_states, local.controls[c.id]) }
  findings  = { for c in local.catalogue.controls : c.id => local.controls[c.id] if !c.mandatory && !contains(local.ok_states, local.controls[c.id]) }
  ready = {
    jira       = length([for id, dep in local.blocking : id if contains(dep, "jira")]) == 0
    confluence = length([for id, dep in local.blocking : id if contains(dep, "confluence")]) == 0
  }
}
