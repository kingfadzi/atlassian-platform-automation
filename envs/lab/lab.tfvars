# The personal lab tenant. This is the only per-environment file operators edit; no secrets
# (credentials arrive as TF_VAR_* from the pipeline) and no instances (projects, spaces, groups
# and people are JSM and AD concerns; the engine only judges them).

tenant = {
  org_id        = "ORG-LAB"                   # Atlassian organisation id (admin.atlassian.com URL)
  directory_id  = "DIR-LAB"                   # directory id from stages/bootstrap output
  site_url      = "https://lab.atlassian.net" # Jira and Confluence site
  group_pattern = "^lab-"                     # AD-managed groups that may hold a role on an instance
}

foundation = {
  domains               = [] # fill once the lab organisation has a verified domain
  product_access_groups = [] # empty = report default access groups without judging them
  banner_contains       = "governed"
  approved_realms       = ["global"] # what this site reports; the lab is permitted global in policy
}
