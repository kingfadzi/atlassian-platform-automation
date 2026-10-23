# Stage: release. Observe only. Proves the admitted assets behave as the standard says:
# an audience member can see them, an outsider and an anonymous caller cannot.
# Each probe is a data source; each expectation is a check that lands in the plan JSON.

locals {
  probes = {
    allowed   = local.allowed_auth
    denied    = local.denied_auth
    anonymous = ""
  }
}

data "http" "project" {
  for_each        = local.probes
  url             = "${var.tenant.site_url}/rest/api/3/project/${var.jira.project.key}"
  request_headers = each.value == "" ? { Accept = "application/json" } : { Authorization = each.value, Accept = "application/json" }
}

data "http" "space" {
  for_each        = local.probes
  url             = "${var.tenant.site_url}/wiki/api/v2/spaces?keys=${var.confluence.space.key}"
  request_headers = each.value == "" ? { Accept = "application/json" } : { Authorization = each.value, Accept = "application/json" }
}

locals {
  space_visible = { for k, r in data.http.space : k => r.status_code == 200 && length(try(jsondecode(r.response_body).results, [])) > 0 }
}

check "project_visibility" {
  assert {
    condition     = data.http.project["allowed"].status_code == 200
    error_message = "Allowed identity cannot read project ${var.jira.project.key} (HTTP ${data.http.project["allowed"].status_code})."
  }
  assert {
    condition     = contains([401, 403, 404], data.http.project["denied"].status_code)
    error_message = "Denied identity can read project ${var.jira.project.key} (HTTP ${data.http.project["denied"].status_code})."
  }
  assert {
    condition     = contains([401, 403, 404], data.http.project["anonymous"].status_code)
    error_message = "Anonymous caller can read project ${var.jira.project.key} (HTTP ${data.http.project["anonymous"].status_code})."
  }
}

check "space_visibility" {
  assert {
    condition     = local.space_visible["allowed"]
    error_message = "Allowed identity cannot see space ${var.confluence.space.key}."
  }
  assert {
    condition     = !local.space_visible["denied"] && !local.space_visible["anonymous"]
    error_message = "Space ${var.confluence.space.key} is visible to a denied or anonymous caller."
  }
}

output "visibility" {
  value = {
    project = { for k, r in data.http.project : k => r.status_code }
    space   = local.space_visible
  }
}
