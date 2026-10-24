# One site-wide Jira project role. Created once by the foundation; projects bind groups to it.
# Never deleted or renamed by Terraform.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "role" {
  path         = "/rest/api/3/role"
  id_attribute = "id"
  data = jsonencode({
    name        = var.name
    description = var.description
  })
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

check "role_matches_policy" {
  assert {
    condition     = restapi_object.role.api_data["name"] == var.name
    error_message = "Drift: project role ${restapi_object.role.id} is named '${restapi_object.role.api_data["name"]}', policy says '${var.name}'."
  }
}
