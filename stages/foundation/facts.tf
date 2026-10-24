# Stage: foundation, part 2. Facts: how a property of the tenant is read. Every fact has the
# same shape, { known, value }, so the evaluation never looks at an HTTP response.
#
# Vocabulary available to policy/foundation.yaml `fact:` (add a block here for a new fact):
#   anonymous_jira_projects          number   projects visible with no credentials
#   anonymous_confluence_spaces      number   spaces visible with no credentials
#   scheme_grants_to_anyone          list     "<scheme>:<permission>" granted to holder type anyone
#   scheme_browse_for_all_licensed   list     schemes granting BROWSE_PROJECTS to applicationRole
#   latest_org_audit_event           string   RFC 3339 time of the newest organisation audit event
#   verified_domains                 list     domain names on the organisation
#   enabled_policy_types             list     org policy types with status enabled
#   confluence_audit_retention_days  number   Confluence audit retention converted to days
#   announcement_banner_text         string   banner message when enabled, else ""
#   default_access_groups            list     default product-access groups across application roles
#   attestation                      map      attestation id => recorded (RFC 3339), from runtime_dir

locals {
  http = {
    anon_jira = data.http.anonymous_jira, anon_conf = data.http.anonymous_confluence,
    schemes   = data.http.permission_schemes, events = data.http.org_events, roles = data.http.application_roles,
    domains   = data.http.domains, policies = data.http.policies, retention = data.http.confluence_audit_retention,
    banner    = data.http.announcement_banner, workspaces = data.http.workspaces,
  }
  status = { for k, d in local.http : k => d.status_code }
  json   = { for k, d in local.http : k => try(jsondecode(d.response_body), {}) }

  schemes        = try(local.json.schemes.permissionSchemes, [])
  retention_unit = { DAYS = 1, WEEKS = 7, MONTHS = 30, YEARS = 365, DECADES = 3650, FOREVER = 36500 }
  attestations   = try(yamldecode(file("${var.runtime_dir}/attestations.yaml")).records, [])

  # Plan names ordered so a requirement can be stated with at_least. The workspaces payload
  # carries no trial flag, so only the plan is observable.
  plan_order    = { None = 0, Free = 1, Standard = 2, Premium = 3, Enterprise = 4 }
  product_plans = { for w in try(local.json.workspaces.data, []) : w.attributes.typeKey => try(w.relationships.entitlement[0].attributes.plan, "None") }

  refused = [401, 403, 404]

  facts = {
    # A refusal is a reading, not a failure to read: Confluence answers 404 to an
    # unauthenticated space list and Jira can answer 403. stages/release uses the same set.
    anonymous_jira_projects = {
      known = contains(local.refused, local.status.anon_jira) || local.status.anon_jira == 200
      value = contains(local.refused, local.status.anon_jira) ? 0 : try(local.json.anon_jira.total, 0)
    }
    anonymous_confluence_spaces = {
      known = contains(local.refused, local.status.anon_conf) || local.status.anon_conf == 200
      value = contains(local.refused, local.status.anon_conf) ? 0 : length(try(local.json.anon_conf.results, []))
    }
    scheme_grants_to_anyone = {
      known = local.status.schemes == 200
      value = flatten([for s in local.schemes : [for p in try(s.permissions, []) : "${s.name}:${p.permission}" if try(p.holder.type, "") == "anyone"]])
    }
    scheme_browse_for_all_licensed = {
      known = local.status.schemes == 200
      value = [for s in local.schemes : s.name if anytrue([for p in try(s.permissions, []) : p.permission == "BROWSE_PROJECTS" && try(p.holder.type, "") == "applicationRole"])]
    }
    latest_org_audit_event = {
      known = local.status.events == 200
      value = try(local.json.events.data[0].attributes.time, null)
    }
    verified_domains = {
      known = local.status.domains == 200
      value = try([for d in local.json.domains.data : d.attributes.name], [])
    }
    enabled_policy_types = {
      known = local.status.policies == 200
      value = try([for p in local.json.policies.data : p.attributes.type if p.attributes.status == "enabled"], [])
    }
    confluence_audit_retention_days = {
      known = local.status.retention == 200
      value = try(local.json.retention.number * local.retention_unit[local.json.retention.units], 0)
    }
    announcement_banner_text = {
      known = local.status.banner == 200
      value = try(local.json.banner.isEnabled, false) ? try(local.json.banner.message, "") : ""
    }
    default_access_groups = {
      known = local.status.roles == 200
      value = try(flatten([for r in local.json.roles : r.defaultGroups]), [])
    }
    attestation = {
      known = true
      value = { for r in local.attestations : r.id => r.recorded if r.kind == "attestation" }
    }
    jira_plan_rank = {
      known = local.status.workspaces == 200
      value = max(concat([0], [for k, p in local.product_plans : lookup(local.plan_order, p, 0) if startswith(k, "jira")])...)
    }
    confluence_plan_rank = {
      known = local.status.workspaces == 200
      value = lookup(local.plan_order, lookup(local.product_plans, "confluence", "None"), 0)
    }
    product_plans = {
      known = local.status.workspaces == 200
      value = local.product_plans
    }
  }
}
