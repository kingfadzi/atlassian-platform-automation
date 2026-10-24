# Stage: admit. The first restricted assets: a Jira permission scheme and project, a
# Confluence space and its group permissions. Groups are referenced by name and must
# already exist (stage identity) and the shared foundation must be ready (foundation.tf). Governance context is stamped into descriptions so
# the tenant itself shows which authority admitted each asset.

# The asset standard is data: policy/standards/<governance.standard>.yaml. Nothing granted
# below is decided in HCL.
locals {
  stamp = templatestring(local.standard.description_template, {
    business_authority = var.governance.business_authority
    standard           = var.governance.standard
    classification     = var.governance.classification
  })
}

module "scheme" {
  source    = "../../modules/jira_permission_scheme"
  providers = { restapi = restapi.jira }

  foundation_ready     = local.jira_ready
  foundation_why       = local.foundation_why
  name                 = var.jira.scheme.name
  description          = local.stamp
  audience_groups      = var.jira.scheme.audience_groups
  admin_groups         = var.jira.scheme.admin_groups
  audience_permissions = local.standard.jira.audience_permissions
  admin_permissions    = local.standard.jira.admin_permissions
}

module "project" {
  source    = "../../modules/jira_project"
  providers = { restapi = restapi.jira }

  foundation_ready     = local.jira_ready
  foundation_why       = local.foundation_why
  key                  = var.jira.project.key
  name                 = var.jira.project.name
  description          = local.stamp
  project_type_key     = var.jira.project.type
  project_template_key = var.jira.project.template
  lead_account_id      = var.jira.project.lead_account_id
  assignee_type        = local.standard.jira.assignee_type
  permission_scheme_id = module.scheme.id
  site_url             = var.tenant.site_url
  authorization_header = local.site_basic_auth
}

module "space" {
  source    = "../../modules/confluence_space"
  providers = { restapi = restapi.confluence }

  foundation_ready = local.confluence_ready
  foundation_why   = local.foundation_why
  key              = var.confluence.space.key
  name             = var.confluence.space.name
}

module "space_permission" {
  source    = "../../modules/confluence_space_permission"
  providers = { restapi = restapi.confluence }

  space_key  = module.space.key
  space_id   = module.space.id
  groups     = var.confluence.space.audience_groups
  operations = local.standard.confluence.audience_operations
}

output "standard" {
  value = { id = local.standard.id, effective_from = local.standard.effective_from }
}
output "scheme_id" { value = module.scheme.id }
output "project_id" { value = module.project.id }
output "space_id" { value = module.space.id }
output "space_permission_ids" { value = module.space_permission.grant_ids }
