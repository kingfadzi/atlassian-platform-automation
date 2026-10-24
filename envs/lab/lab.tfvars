# Intent for the personal lab. This is the file operators edit. No secrets here: credentials
# arrive as TF_VAR_* variables from the pipeline (see envs/shared/credentials.tf).

tenant = {
  org_id       = "b7be76cf-b203-479a-8b29-c511f513c0e2"   # Atlassian organisation id (admin.atlassian.com URL)
  directory_id = "4977f1fe-cae7-4fa3-91ee-41d616475d8a"   # directory id from stages/bootstrap output
  site_url     = "https://butterflycluster.atlassian.net" # Jira and Confluence site
  scope_regex  = "^lab-"                                  # every managed group name must match
}

groups = {
  lab-admins    = "LAB administrators"
  lab-team      = "LAB team"
  lab-outsiders = "LAB outsiders (negative probe only)"
}

# Group membership. Replace the placeholders with real Atlassian accountIds (24-char ids from
# the bootstrap output or admin.atlassian.com); lab-outsiders stays empty on purpose so the
# release stage has a genuine negative probe.
memberships = {
  lab-admins = ["70121:37f2de15-90fb-4712-aad2-1750dba383df"] # bootstrap output automation_account_id
  # lab-team is intentionally empty until the allowed probe account exists; the release stage
  # cannot pass until its accountId is listed here.
}

jira = {
  scheme = {
    name            = "LAB Restricted"
    audience_groups = ["lab-admins", "lab-team"]
    admin_groups    = ["lab-admins"]
  }
  project = {
    key  = "LABR"
    name = "LAB Restricted"
    # This site has no Jira Software licence (only service_desk, customer_service and business
    # are accessible), so a company-managed business project is the only fit that still binds a
    # permission scheme - team-managed projects ignore schemes entirely.
    type            = "business"
    template        = "com.atlassian.jira-core-project-templates:jira-core-project-management"
    lead_account_id = "70121:37f2de15-90fb-4712-aad2-1750dba383df"
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

foundation = {
  domains               = [] # fill once the lab organisation has a verified domain
  product_access_groups = [] # empty = report default access groups without judging them
  banner_contains       = "governed"
  # Free cannot restrict Jira permission schemes or Confluence spaces. This lab deliberately
  # runs on Free and trial plans, so the two entitlement controls report findings and the
  # deviation is carried as a dated exception in runtime/lab/exceptions.yaml.
  minimum_plan = "Standard"
}
