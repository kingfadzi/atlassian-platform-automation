# Stage: conform, part 2. Per-instance facts: the vocabulary policy/conformance.yaml may use.
# Each fact is { known, value }. Add a fact here and in observe.tf; never a control id.
#
#   stamp                  bool    the instance names a known standard (property or label)
#   standard_superseded    bool    the standard it is judged against has a successor
#   scheme_id              string  (jira) permission scheme id of the project
#   user_actors            list    (jira) users holding a platform role directly
#   groups_outside_pattern list    (jira) groups on platform roles not matching tenant.group_pattern
#   admin_group_count      number  (jira) groups bound to the admin role
#   lead_active            bool    (jira) project lead account is active
#   last_activity          string  RFC 3339 of the latest issue update or page change
#   space_role_names       list    (confluence) role names assigned on the space
#   public_principals      list    holders that make the instance public (policy.public)

locals {
  scheme_to_standard = { for id, s in local.contract.standards : tostring(s.scheme_id) => id }
  label_prefix       = local.policy.stamp.confluence_label_prefix
  pub                = local.policy.public

  # Jira projects --------------------------------------------------------------------------
  project_stamp = { for k, p in local.projects : k => try(tostring(p.properties[local.stamp_prop]), null) }
  project_std = { for k, p in local.projects : k => coalesce(
    contains(keys(local.standards), coalesce(local.project_stamp[k], "-")) ? local.project_stamp[k] : null,
    lookup(local.scheme_to_standard, tostring(try(jsondecode(data.http.project_scheme[k].response_body).id, "")), null),
    local.policy.fallback_standard,
  ) }
  actors = { for k, _ in local.projects : k => { for role in keys(local.role_ids) :
    role => try(jsondecode(data.http.project_role_actors["${k}:${role}"].response_body).actors, [])
  } }
  group_actors = { for k, roles in local.actors : k => flatten([for role, a in roles : [for x in a : x.name if x.type == "atlassian-group-role-actor"]]) }

  project_facts = { for k, p in local.projects : k => {
    stamp               = { known = true, value = contains(keys(local.standards), coalesce(local.project_stamp[k], "-")) }
    standard_superseded = { known = true, value = anytrue([for s in local.standards : try(s.supersedes, null) == local.project_std[k]]) }
    scheme_id = {
      known = data.http.project_scheme[k].status_code == 200
      value = tostring(try(jsondecode(data.http.project_scheme[k].response_body).id, ""))
    }
    user_actors = {
      known = alltrue([for role in keys(local.role_ids) : data.http.project_role_actors["${k}:${role}"].status_code == 200])
      value = flatten([for role, a in local.actors[k] : [for x in a : x.displayName if x.type == "atlassian-user-role-actor"]])
    }
    groups_outside_pattern = { known = true, value = [for g in local.group_actors[k] : g if !can(regex(var.tenant.group_pattern, g))] }
    admin_group_count      = { known = true, value = length([for x in try(local.actors[k]["admin"], []) : x if x.type == "atlassian-group-role-actor"]) }
    lead_active            = { known = can(p.lead.active), value = try(p.lead.active, false) }
    last_activity = {
      known = can(p.insight.lastIssueUpdateTime)
      value = try(replace(p.insight.lastIssueUpdateTime, "/([+-]\\d{2})(\\d{2})$/", "$1:$2"), null)
    }
    public_principals = {
      known = data.http.project_scheme[k].status_code == 200
      value = [for g in try(jsondecode(data.http.project_scheme[k].response_body).permissions, []) : g.holder.type
      if g.permission == "BROWSE_PROJECTS" && contains(local.pub.jira_holder_types, try(g.holder.type, ""))]
    }
  } }

  # Confluence spaces ----------------------------------------------------------------------
  space_role_name = { for r in try(jsondecode(data.http.site_space_roles.response_body).results, []) : tostring(r.id) => r.name }
  space_labels    = { for k, s in local.spaces : k => [for l in try(jsondecode(data.http.space_labels[k].response_body).results, []) : l.name] }
  space_stamp     = { for k, labels in local.space_labels : k => try(one([for l in labels : trimprefix(l, local.label_prefix) if startswith(l, local.label_prefix)]), null) }
  space_std       = { for k, _ in local.spaces : k => contains(keys(local.standards), coalesce(local.space_stamp[k], "-")) ? local.space_stamp[k] : local.policy.fallback_standard }
  space_perms     = { for k, _ in local.spaces : k => try(jsondecode(data.http.space_permissions[k].response_body).results, []) }

  space_facts = { for k, s in local.spaces : k => {
    stamp               = { known = data.http.space_labels[k].status_code == 200, value = contains(keys(local.standards), coalesce(local.space_stamp[k], "-")) }
    standard_superseded = { known = true, value = anytrue([for x in local.standards : try(x.supersedes, null) == local.space_std[k]]) }
    last_activity = {
      known = data.http.space_latest_page[k].status_code == 200
      value = try(jsondecode(data.http.space_latest_page[k].response_body).results[0].version.createdAt, null)
    }
    space_role_names = {
      known = data.http.space_roles[k].status_code == 200
      value = distinct([for a in try(jsondecode(data.http.space_roles[k].response_body).results, []) : lookup(local.space_role_name, tostring(a.roleId), "?")])
    }
    public_principals = {
      known = data.http.space_permissions[k].status_code == 200
      value = [for p in local.space_perms[k] : "${p.principal.type}:${try(p.principal.id, "")}"
      if contains(local.pub.confluence_principal_types, p.principal.type) || (p.principal.type == "group" && contains(local.pub.confluence_groups, try(p.principal.id, "")))]
    }
  } }
}
