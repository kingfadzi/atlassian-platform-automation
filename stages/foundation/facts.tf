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
#   domains_missing_verification_record list  declared domains whose verification TXT record no longer resolves
#   domains_claimed_by_other_orgs    list     declared domains a second organisation has also verified
#   product_realms                   list     residency realms of the products on this site
#   confluence_audit_retention_days  number   Confluence audit retention converted to days
#   announcement_banner_text         string   banner message when enabled, else ""
#   default_access_groups            list     default product-access groups across application roles
#   manual_confirmation              map      control id => recorded (RFC 3339), from records_dir
#   jira_project_roles               list     site-wide project role names
#   permission_scheme_names          list     permission scheme names on the site
#   scheme_grants                    list     "scheme name|PERMISSION|role name" for every grant to a project role
#   confluence_space_roles           list     space role names available on the site
#   site_admin_accounts              list     account ids in the admin groups named in policy/identities.yaml
#   exceptional_identities_last_review string RFC 3339 of the oldest review in policy/identities.yaml
#   jira_application_plans           map      Jira application id => UNLICENSED | FREE | PAID (instance license)
#   jira_paid_application_count      number   Jira applications on a PAID plan
#   confluence_seat_capacity         number   seat capacity of the Confluence workspace (admin API); Confluence has no plan API
#   (treatment.tf)  service_project_keys, issue_type_names, custom_field_names, treatment_request_types, import_current_<id>

locals {
  http = {
    anon_jira = data.http.anonymous_jira, anon_conf = data.http.anonymous_confluence,
    schemes   = data.http.permission_schemes, events = data.http.org_events, roles = data.http.application_roles,
    domains   = data.http.domains, retention = data.http.confluence_audit_retention,
    banner    = data.http.announcement_banner, project_roles = data.http.project_roles, space_roles = data.http.space_roles,
    license   = data.http.jira_license, workspaces = data.http.workspaces,
  }
  # Matched on the site URL prefix: a product hostUrl carries its own path ("<site>/wiki"), and
  # some workspaces report no hostUrl at all.
  site_workspaces      = [for w in try(local.json.workspaces.data, []) : w if startswith(try(w.attributes.hostUrl, ""), var.tenant.site_url)]
  confluence_workspace = try(one([for w in local.site_workspaces : w if w.attributes.typeKey == "confluence"]), null)
  role_name_by_id      = { for r in try(local.json.project_roles, []) : tostring(r.id) => r.name }
  admin_member_status  = { for g, d in data.http.admin_group_members : g => d.status_code }
  admin_members        = flatten([for g, d in data.http.admin_group_members : try([for m in jsondecode(d.response_body).values : m.accountId], [])])
  # NOERROR and NXDOMAIN are both definitive answers; any other Status means the resolver did not answer.
  txt_json       = { for k, d in data.http.domain_txt : k => try(jsondecode(d.response_body), {}) }
  txt_definitive = alltrue([for k, d in data.http.domain_txt : d.status_code == 200 && contains([0, 3], try(local.txt_json[k].Status, -1))])
  domain_has_record = { for d in var.foundation.domains : d => anytrue(flatten([for r in var.dns_resolvers :
    [for a in try(local.txt_json["${d}|${r}"].Answer, []) : strcontains(replace(a.data, "\"", ""), "atlassian-domain-verification=")]
  ])) }
  org_domains = try(local.json.domains.data, [])
  status      = { for k, d in local.http : k => d.status_code }
  json        = { for k, d in local.http : k => try(jsondecode(d.response_body), {}) }

  schemes              = try(local.json.schemes.permissionSchemes, [])
  retention_unit       = { DAYS = 1, WEEKS = 7, MONTHS = 30, YEARS = 365, DECADES = 3650, FOREVER = 36500 }
  manual_confirmations = try(yamldecode(file("${var.records_dir}/manual_confirmations.yaml")).records, [])
  import_records       = try(yamldecode(file("${var.records_dir}/imports.yaml")).records, [])

  tenant_facts = {
    anonymous_jira_projects = {
      known = contains([200, 401], local.status.anon_jira)
      value = local.status.anon_jira == 401 ? 0 : try(local.json.anon_jira.total, 0)
    }
    anonymous_confluence_spaces = {
      known = contains([200, 401], local.status.anon_conf)
      value = local.status.anon_conf == 401 ? 0 : length(try(local.json.anon_conf.results, []))
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
    # Presence of a verification record, not proof it is this organisation's: the API does not
    # expose the expected token, so claim.status remains the authority on the token itself.
    domains_missing_verification_record = {
      known = length(var.dns_resolvers) > 0 && local.txt_definitive
      value = [for d, present in local.domain_has_record : d if !present]
    }
    domains_claimed_by_other_orgs = {
      known = local.status.domains == 200 && alltrue([for d in local.org_domains : try(d.attributes.verifiedOrgsQuantity, null) != null])
      value = [for d in local.org_domains : d.attributes.name if try(d.attributes.verifiedOrgsQuantity, 0) > 1]
    }
    product_realms = {
      known = local.status.workspaces == 200 && length(local.site_workspaces) > 0
      value = distinct([for w in local.site_workspaces : try(w.attributes.realm, "unknown")])
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
    manual_confirmation = {
      known = true
      value = { for r in local.manual_confirmations : r.id => r.recorded if r.kind == "manual_confirmation" }
    }
    jira_project_roles = {
      known = local.status.project_roles == 200
      value = try([for r in local.json.project_roles : r.name], [])
    }
    permission_scheme_names = {
      known = local.status.schemes == 200
      value = [for s in local.schemes : s.name]
    }
    scheme_grants = {
      known = local.status.schemes == 200 && local.status.project_roles == 200
      value = flatten([for s in local.schemes : [
        for p in try(s.permissions, []) : "${s.name}|${p.permission}|${lookup(local.role_name_by_id, tostring(try(p.holder.parameter, "")), "?")}"
        if try(p.holder.type, "") == "projectRole"
      ]])
    }
    confluence_space_roles = {
      known = local.status.space_roles == 200
      value = try([for r in local.json.space_roles.results : r.name], [])
    }
    site_admin_accounts = {
      known = alltrue([for g, c in local.admin_member_status : c == 200])
      value = distinct(local.admin_members)
    }
    jira_application_plans = {
      known = local.status.license == 200
      value = { for a in try(local.json.license.applications, []) : a.id => a.plan }
    }
    jira_paid_application_count = {
      known = local.status.license == 200
      value = length([for a in try(local.json.license.applications, []) : a if a.plan == "PAID"])
    }
    # Seat capacity is on the entitlement, not the workspace: the workspace attributes carry no
    # capacity field at all, so reading it there leaves this fact permanently unknown.
    confluence_seat_capacity = {
      known = local.status.workspaces == 200 && can(local.confluence_workspace.relationships.entitlement[0].attributes.softCapacityLimit)
      value = try(local.confluence_workspace.relationships.entitlement[0].attributes.softCapacityLimit, null)
    }
    exceptional_identities_last_review = {
      known = true
      value = try(sort([for a in local.identities.accounts : a.reviewed])[0], null)
    }
  }
}

locals {
  facts = merge(local.tenant_facts, local.treatment_facts) # treatment facts: treatment.tf
}
