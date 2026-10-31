# Stage: foundation, part 0b. The asset-treatment service (policy/treatment.yaml): the JSM project
# users onboard assets through, its Asset issue type and fields, and its request types. What has
# no write API (workflow, automation) is declared in jsm/ and bound to its file hash. Everything
# is read back and judged by controls with depends: [treatment].

locals {
  treatment    = yamldecode(file("${path.module}/../../policy/treatment.yaml"))
  lead_account = one([for a in local.identities.accounts : a.id if a.kind == local.treatment.project.lead])
}

module "treatment_project" {
  source    = "../../modules/jira_project"
  providers = { restapi = restapi.jira }

  key                  = local.treatment.project.key
  name                 = local.treatment.project.name
  description          = local.treatment.project.description
  project_type_key     = local.treatment.project.type
  project_template_key = local.treatment.project.template
  lead_account_id      = local.lead_account
}

module "asset_type" {
  source    = "../../modules/jira_issue_type"
  providers = { restapi = restapi.jira }

  name        = local.treatment.asset.issue_type
  description = local.treatment.asset.description
}

data "http" "treatment_issue_type_scheme" {
  url             = "${var.tenant.site_url}/rest/api/3/issuetypescheme/project?projectId=${module.treatment_project.id}"
  request_headers = local.site_auth
}

module "asset_type_in_project" {
  source    = "../../modules/jira_issue_type_in_scheme"
  providers = { restapi = restapi.jira }

  scheme_id     = tostring(jsondecode(data.http.treatment_issue_type_scheme.response_body).values[0].issueTypeScheme.id)
  issue_type_id = module.asset_type.id
}

module "asset_field" {
  for_each  = { for f in local.treatment.asset.fields : f.id => f }
  source    = "../../modules/jira_custom_field"
  providers = { restapi = restapi.jira }

  name        = each.value.name
  description = "Asset record field '${each.key}' | managed by platform automation"
  type        = local.treatment.field_types[each.value.type].type
  searcher    = local.treatment.field_types[each.value.type].searcher
}

module "request_type" {
  for_each  = { for r in local.treatment.request_types : r.id => r }
  source    = "../../modules/jsm_request_type"
  providers = { restapi = restapi.jira }

  service_desk  = module.treatment_project.key
  name          = each.value.name
  description   = each.value.description
  issue_type_id = module.asset_type.id
  depends_on    = [module.asset_type_in_project]
}

# Read back ----------------------------------------------------------------------------------
data "http" "projects" {
  url             = "${var.tenant.site_url}/rest/api/3/project/search?maxResults=100"
  request_headers = local.site_auth
  depends_on      = [module.treatment_project]
}
data "http" "issue_types" {
  url             = "${var.tenant.site_url}/rest/api/3/issuetype"
  request_headers = local.site_auth
  depends_on      = [module.asset_type]
}
data "http" "fields" {
  url             = "${var.tenant.site_url}/rest/api/3/field"
  request_headers = local.site_auth
  depends_on      = [module.asset_field]
}
data "http" "request_types" {
  url             = "${var.tenant.site_url}/rest/servicedeskapi/servicedesk/${local.treatment.project.key}/requesttype"
  request_headers = local.site_auth
  depends_on      = [module.request_type]
}

locals {
  import_by_id = { for r in local.import_records : r.id => r if r.kind == "import" }
  treatment_facts = merge(
    {
      service_project_keys = {
        known = data.http.projects.status_code == 200
        value = [for p in try(jsondecode(data.http.projects.response_body).values, []) : p.key if try(p.projectTypeKey, "") == "service_desk"]
      }
      issue_type_names = {
        known = data.http.issue_types.status_code == 200
        value = [for t in try(jsondecode(data.http.issue_types.response_body), []) : t.name]
      }
      custom_field_names = {
        known = data.http.fields.status_code == 200
        value = [for f in try(jsondecode(data.http.fields.response_body), []) : f.name if try(f.custom, false)]
      }
      treatment_request_types = {
        known = data.http.request_types.status_code == 200
        value = [for r in try(jsondecode(data.http.request_types.response_body).values, []) : r.name]
      }
    },
    { for i in local.treatment.imports : "import_current_${i.id}" => {
      known = true
      value = try(local.import_by_id[i.id].sha256, "") == filesha256("${path.module}/../../${i.file}")
    } },
  )
  treatment_intent = {
    "policy.treatment_project_keys" = [local.treatment.project.key]
    "policy.asset_issue_type"       = [local.treatment.asset.issue_type]
    "policy.asset_field_names"      = [for f in local.treatment.asset.fields : f.name]
    "policy.request_type_names"     = [for r in local.treatment.request_types : r.name]
  }
  treatment_contract = {
    project_key   = module.treatment_project.key
    issue_type_id = module.asset_type.id
    field_ids     = { for id, m in module.asset_field : id => m.id }
    request_types = { for id, m in module.request_type : id => m.id }
    imports       = { for i in local.treatment.imports : i.id => filesha256("${path.module}/../../${i.file}") }
  }
}
