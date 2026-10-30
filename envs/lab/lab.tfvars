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
  domains               = ["lab.example", "lab.test"] # every TLD accounts sign in with; each must be verified
  product_access_groups = []                          # empty = report default access groups without judging them
  banner_contains       = "governed"
  approved_realms       = ["global"] # what this site reports; the lab is permitted global in policy
}

# Resolvers the verification TXT records are read through. Unset here because the domains above do
# not exist; an environment with real domains declares the resolvers it can reach, e.g.
# dns_resolvers = ["https://dns.google/resolve", "https://cloudflare-dns.com/dns-query"]
