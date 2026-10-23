# Intent for the personal lab. This is the file operators edit. No secrets here: credentials
# arrive as TF_VAR_* variables from the pipeline (see envs/shared/credentials.tf).

tenant = {
  org_id       = "ORG-LAB"                   # Atlassian organisation id (admin.atlassian.com URL)
  directory_id = "DIR-LAB"                   # directory id from stages/bootstrap output
  site_url     = "https://lab.atlassian.net" # Jira and Confluence site
  scope_regex  = "^lab-"                     # every managed group name must match
}

groups = {
  lab-admins    = "LAB administrators"
  lab-team      = "LAB team"
  lab-outsiders = "LAB outsiders (negative probe only)"
}

jira = {
  scheme = {
    name            = "LAB Restricted"
    audience_groups = ["lab-admins", "lab-team"]
    admin_groups    = ["lab-admins"]
  }
  project = {
    key             = "LABR"
    name            = "LAB Restricted"
    type            = "software"
    template        = "com.pyxis.greenhopper.jira:gh-simplified-kanban-classic"
    lead_account_id = "USER-LAB-ADMIN"
    assignee_type   = "UNASSIGNED"
  }
}

confluence = {
  space = {
    key             = "LABP"
    name            = "LAB Private"
    audience_groups = ["lab-admins", "lab-team"]
  }
}

governance = {
  business_authority = "BA-LAB-001"
  classification     = "Internal"
  standard           = "restricted-collab-v1"
  authority_records  = ["AUTH-APP-01", "OWN-01", "CLS-01", "APR-01"]
}

identities = {
  admin    = "USER-LAB-ADMIN"
  reviewer = "USER-LAB-REVIEWER"
  allowed  = "USER-LAB-ALLOWED"
  denied   = "USER-LAB-DENIED"
}
