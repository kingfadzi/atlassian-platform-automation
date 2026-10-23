# Stage: bootstrap. Observe only. Confirms the tenancy, products and automation identity
# the intent assumes before anything is created. Owns no resources; its state holds only
# the observations, which the governance gate reads as `checks` in the plan JSON.

data "http" "org" {
  url             = "${var.admin_api_url}/v1/orgs/${var.tenant.org_id}"
  request_headers = { Authorization = "Bearer ${var.atlassian_org_api_key}", Accept = "application/json" }
}

data "http" "directories" {
  url             = "${var.admin_api_url}/v2/orgs/${var.tenant.org_id}/directories"
  request_headers = { Authorization = "Bearer ${var.atlassian_org_api_key}", Accept = "application/json" }
}

data "http" "workspaces" {
  url             = "${var.admin_api_url}/v2/orgs/${var.tenant.org_id}/workspaces"
  method          = "POST"
  request_body    = jsonencode({ limit = 50 })
  request_headers = { Authorization = "Bearer ${var.atlassian_org_api_key}", Accept = "application/json", Content-Type = "application/json" }
}

data "http" "jira_myself" {
  url             = "${var.tenant.site_url}/rest/api/3/myself"
  request_headers = { Authorization = local.site_basic_auth, Accept = "application/json" }
}

data "http" "confluence_me" {
  url             = "${var.tenant.site_url}/wiki/rest/api/user/current"
  request_headers = { Authorization = local.site_basic_auth, Accept = "application/json" }
}

locals {
  directory_ids = data.http.directories.status_code == 200 ? [for d in jsondecode(data.http.directories.response_body).data : d.directoryId] : []
  workspaces    = data.http.workspaces.status_code == 200 ? jsondecode(data.http.workspaces.response_body).data : []
  site_host     = replace(var.tenant.site_url, "/^https?:\\/\\//", "")
  product_keys  = [for w in local.workspaces : w.attributes.typeKey if endswith(w.attributes.hostUrl, local.site_host)]
}

check "tenancy" {
  assert {
    condition     = data.http.org.status_code == 200 && jsondecode(data.http.org.response_body).data.id == var.tenant.org_id
    error_message = "Organisation ${var.tenant.org_id} is not readable with the supplied org API key."
  }
  assert {
    condition     = contains(local.directory_ids, var.tenant.directory_id)
    error_message = "Directory ${var.tenant.directory_id} is not in organisation ${var.tenant.org_id}. Known: ${join(", ", local.directory_ids)}."
  }
}

check "products" {
  assert {
    condition     = anytrue([for k in local.product_keys : startswith(k, "jira")]) && contains(local.product_keys, "confluence")
    error_message = "Site ${var.tenant.site_url} must host Jira and Confluence. Found: ${join(", ", local.product_keys)}."
  }
}

check "automation_identity" {
  assert {
    condition     = data.http.jira_myself.status_code == 200 && try(jsondecode(data.http.jira_myself.response_body).active, false)
    error_message = "Jira rejected the automation identity (HTTP ${data.http.jira_myself.status_code})."
  }
  assert {
    condition     = data.http.confluence_me.status_code == 200
    error_message = "Confluence rejected the automation identity (HTTP ${data.http.confluence_me.status_code})."
  }
}

output "directory_ids" { value = local.directory_ids }
output "products" { value = local.product_keys }
output "automation_account_id" { value = try(jsondecode(data.http.jira_myself.response_body).accountId, null) }
