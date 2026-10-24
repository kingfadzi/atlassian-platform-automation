# Stage: conform, part 1. Reads every instance in the tenant. Nothing here is created; the
# engine holds no list of instances, it discovers them. One read per project for its scheme and
# per (project, platform role) for the actors; one read per space for labels, role assignments,
# permissions and latest page. Fine for a lab; paginate before an estate.

locals {
  site_auth  = { Authorization = local.site_basic_auth, Accept = "application/json" }
  policy     = yamldecode(file("${path.module}/../../policy/conformance.yaml"))
  standards  = { for f in fileset("${path.module}/../../policy/standards", "*.yaml") : trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/../../policy/standards/${f}")) }
  role_ids   = local.foundation.role_ids
  stamp_prop = local.policy.stamp.jira_property
}

data "http" "projects" {
  url             = "${var.tenant.site_url}/rest/api/3/project/search?maxResults=100&expand=lead,insight&properties=${local.stamp_prop}"
  request_headers = local.site_auth
}

locals {
  projects     = { for p in try(jsondecode(data.http.projects.response_body).values, []) : p.key => p }
  project_role = { for pair in setproduct(keys(local.projects), keys(local.role_ids)) : "${pair[0]}:${pair[1]}" => { key = pair[0], role = pair[1] } }
}

data "http" "project_scheme" {
  for_each        = local.projects
  url             = "${var.tenant.site_url}/rest/api/3/project/${each.key}/permissionscheme?expand=permissions"
  request_headers = local.site_auth
}

data "http" "project_role_actors" {
  for_each        = local.project_role
  url             = "${var.tenant.site_url}/rest/api/3/project/${each.value.key}/role/${local.role_ids[each.value.role]}"
  request_headers = local.site_auth
}

data "http" "spaces" {
  url             = "${var.tenant.site_url}/wiki/api/v2/spaces?limit=250&status=current"
  request_headers = local.site_auth
}

locals {
  spaces = { for s in try(jsondecode(data.http.spaces.response_body).results, []) : s.key => s }
}

data "http" "space_labels" {
  for_each        = local.spaces
  url             = "${var.tenant.site_url}/wiki/api/v2/spaces/${each.value.id}/labels"
  request_headers = local.site_auth
}

data "http" "space_roles" {
  for_each        = local.spaces
  url             = "${var.tenant.site_url}/wiki/api/v2/spaces/${each.value.id}/role-assignments"
  request_headers = local.site_auth
}

data "http" "space_permissions" {
  for_each        = local.spaces
  url             = "${var.tenant.site_url}/wiki/api/v2/spaces/${each.value.id}/permissions"
  request_headers = local.site_auth
}

data "http" "space_latest_page" {
  for_each        = local.spaces
  url             = "${var.tenant.site_url}/wiki/api/v2/spaces/${each.value.id}/pages?sort=-modified-date&limit=1"
  request_headers = local.site_auth
}

data "http" "site_space_roles" {
  url             = "${var.tenant.site_url}/wiki/api/v2/space-roles"
  request_headers = local.site_auth
}
