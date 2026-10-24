# A platform-owned Jira project (the asset-treatment service). Template and lead are create-only
# inputs Jira does not echo back, so they are excluded from drift comparison. Never deleted.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
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
  })
  ignore_server_additions = true
  ignore_changes_to       = ["projectTemplateKey", "leadAccountId"]

  lifecycle { prevent_destroy = true }
}

# On the creating apply api_data holds the create response ({id, key, self}); later plans hold the project.
check "project_matches_policy" {
  assert {
    condition     = lookup(restapi_object.project.api_data, "key", var.key) == var.key && lookup(restapi_object.project.api_data, "name", var.name) == var.name
    error_message = "Drift: project ${restapi_object.project.id} key/name differ from policy (${var.key} / ${var.name})."
  }
}
