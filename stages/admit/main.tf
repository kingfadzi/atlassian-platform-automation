# Stage: admit. The first restricted assets: a Jira permission scheme and project, a
# Confluence space and its group permissions. Groups are referenced by name and must
# already exist (stage identity). Governance context is stamped into descriptions so
# the tenant itself shows which authority admitted each asset.

locals {
  stamp = "${var.governance.business_authority} | ${var.governance.standard} | ${var.governance.classification} | managed by platform automation"
}

module "scheme" {
  source    = "../../modules/jira_permission_scheme"
  providers = { restapi = restapi.jira }

  name            = var.jira.scheme.name
  description     = local.stamp
  audience_groups = var.jira.scheme.audience_groups
  admin_groups    = var.jira.scheme.admin_groups
}

module "project" {
  source    = "../../modules/jira_project"
  providers = { restapi = restapi.jira }

  key                  = var.jira.project.key
  name                 = var.jira.project.name
  description          = local.stamp
  project_type_key     = var.jira.project.type
  project_template_key = var.jira.project.template
  lead_account_id      = var.jira.project.lead_account_id
  assignee_type        = var.jira.project.assignee_type
  permission_scheme_id = module.scheme.id
  site_url             = var.tenant.site_url
  authorization_header = local.site_basic_auth
}

module "space" {
  source    = "../../modules/confluence_space"
  providers = { restapi = restapi.confluence }

  key  = var.confluence.space.key
  name = var.confluence.space.name
}

module "space_permission" {
  source    = "../../modules/confluence_space_permission"
  providers = { restapi = restapi.confluence }

  space_key = module.space.key
  space_id  = module.space.id
  groups    = var.confluence.space.audience_groups
}

output "scheme_id" { value = module.scheme.id }
output "project_id" { value = module.project.id }
output "space_id" { value = module.space.id }
output "space_permission_ids" { value = module.space_permission.grant_ids }
