# Stage: foundation, part 1 (after provision.tf). HTTP reads behind the facts in facts.tf.
# Anonymous probes carry no Authorization header on purpose.

locals {
  site_auth  = { Authorization = local.site_basic_auth, Accept = "application/json" }
  admin_auth = { Authorization = "Bearer ${var.atlassian_org_api_key}", Accept = "application/json" }
  anon       = { Accept = "application/json" }
}

data "http" "anonymous_jira" {
  url             = "${var.tenant.site_url}/rest/api/3/project/search?maxResults=1"
  request_headers = local.anon
}

data "http" "anonymous_confluence" {
  url             = "${var.tenant.site_url}/wiki/api/v2/spaces?limit=1"
  request_headers = local.anon
}

data "http" "permission_schemes" {
  url             = "${var.tenant.site_url}/rest/api/3/permissionscheme?expand=permissions"
  request_headers = local.site_auth
  depends_on      = [module.scheme]
}

data "http" "org_events" {
  url             = "${var.admin_api_url}/v1/orgs/${var.tenant.org_id}/events?limit=1"
  request_headers = local.admin_auth
}

data "http" "application_roles" {
  url             = "${var.tenant.site_url}/rest/api/3/applicationrole"
  request_headers = local.site_auth
}

data "http" "domains" {
  url             = "${var.admin_api_url}/v1/orgs/${var.tenant.org_id}/domains"
  request_headers = local.admin_auth
}

data "http" "policies" {
  url             = "${var.admin_api_url}/v1/orgs/${var.tenant.org_id}/policies"
  request_headers = local.admin_auth
}

data "http" "confluence_audit_retention" {
  url             = "${var.tenant.site_url}/wiki/rest/api/audit/retention"
  request_headers = local.site_auth
}

data "http" "announcement_banner" {
  url             = "${var.tenant.site_url}/rest/api/3/announcementBanner"
  request_headers = local.site_auth
}

data "http" "project_roles" {
  url             = "${var.tenant.site_url}/rest/api/3/role"
  request_headers = local.site_auth
  depends_on      = [module.role]
}

data "http" "space_roles" {
  url             = "${var.tenant.site_url}/wiki/api/v2/space-roles"
  request_headers = local.site_auth
}

data "http" "admin_group_members" {
  for_each        = toset(local.identities.admin_groups)
  url             = "${var.tenant.site_url}/rest/api/3/group/member?groupname=${urlencode(each.value)}&maxResults=200"
  request_headers = local.site_auth
}

data "http" "jira_license" {
  url             = "${var.tenant.site_url}/rest/api/3/instance/license"
  request_headers = local.site_auth
}

data "http" "workspaces" {
  url             = "${var.admin_api_url}/v2/orgs/${var.tenant.org_id}/workspaces"
  method          = "POST"
  request_body    = "{}"
  request_headers = { Authorization = "Bearer ${var.atlassian_org_api_key}", Accept = "application/json", "Content-Type" = "application/json" }
}
