# A Jira project bound to a permission scheme at creation. Template, lead and scheme are
# create-only inputs that Jira does not echo back, so they are excluded from drift
# comparison; the scheme association is verified independently through the project's
# permissionscheme endpoint.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
    http    = { source = "hashicorp/http", version = "~> 3.5" }
  }
}

resource "restapi_object" "project" {
  path         = "/rest/api/3/project"
  id_attribute = "id"
  data = jsonencode({
    key                = var.key
    name               = var.name
    description        = var.description
    projectTypeKey     = var.project_type_key
    projectTemplateKey = var.project_template_key
    leadAccountId      = var.lead_account_id
    assigneeType       = var.assignee_type
    permissionScheme   = tonumber(var.permission_scheme_id)
  })
  ignore_server_additions = true
  ignore_changes_to       = ["projectTemplateKey", "leadAccountId", "permissionScheme"]

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.foundation_ready
      error_message = "Shared foundation is not ready for Jira: ${var.foundation_why}. Fix the foundation stage first."
    }
  }
}

data "http" "project_scheme" {
  url             = "${var.site_url}/rest/api/3/project/${restapi_object.project.id}/permissionscheme"
  request_headers = { Authorization = var.authorization_header, Accept = "application/json" }
}

# On the apply that creates the project, api_data holds Jira's create response ({id, key,
# self}); every later plan holds the full project, so lookup() defaults only cover that first pass.
check "project_matches_intent" {
  assert {
    condition     = lookup(restapi_object.project.api_data, "key", var.key) == var.key && lookup(restapi_object.project.api_data, "name", var.name) == var.name
    error_message = "Drift: project ${restapi_object.project.id} key/name differ from intent (${var.key} / ${var.name})."
  }
  assert {
    condition     = data.http.project_scheme.status_code == 200 && tostring(jsondecode(data.http.project_scheme.response_body).id) == tostring(var.permission_scheme_id)
    error_message = "Drift: project ${var.key} is not bound to permission scheme ${var.permission_scheme_id}."
  }
}
