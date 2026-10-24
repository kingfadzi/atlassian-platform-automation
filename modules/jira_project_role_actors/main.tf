# Binds groups to a project role in one project. The role and the scheme granting to it come
# from the foundation; only the groups vary per asset. Adding actors is idempotent on the API
# side; nothing is removed by Terraform (drift is reported by the check).

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "actors" {
  path         = "/rest/api/3/project/${var.project_key}/role"
  object_id    = tostring(var.role_id)
  id_attribute = "id"
  data         = jsonencode({ group = var.groups })
  # The read is GET /project/{key}/role/{roleId}; the id is the role id, known up front.
  create_path = "/rest/api/3/project/${var.project_key}/role/${var.role_id}"
  read_path   = "/rest/api/3/project/${var.project_key}/role/${var.role_id}"

  ignore_server_additions = true
  lifecycle { prevent_destroy = true }
}

locals {
  bound = try([for a in jsondecode(restapi_object.actors.api_response).actors : a.name if a.type == "atlassian-group-role-actor"], [])
}

check "actors_match_intent" {
  assert {
    condition     = length(setsubtract(var.groups, local.bound)) == 0
    error_message = "Drift: role ${var.role_id} in ${var.project_key} is missing groups ${join(", ", setsubtract(var.groups, local.bound))}."
  }
}
