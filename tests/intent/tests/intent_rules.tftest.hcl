# Structural rules of the intent, proven without any tenant or provider.
# Run with: terraform -chdir=tests/intent test

variables {
  tenant = { org_id = "o", directory_id = "d", site_url = "https://lab.atlassian.net", scope_regex = "^lab-" }
  groups = { lab-admins = "a", lab-team = "t", lab-outsiders = "o" }
  jira = {
    project = { key = "LABR", name = "LAB Restricted", type = "software", template = "x", lead_account_id = "u", roles = { admin = ["lab-admins"], member = ["lab-team"] } }
  }
  confluence = { space = { key = "LABP", name = "LAB Private", audience_groups = ["lab-admins", "lab-team"] } }
  governance = { business_authority = "BA-LAB-001", classification = "Internal", standard = "restricted-collab-v1", authority_records = ["AUTH-APP-01"] }
  identities = { admin = "a", reviewer = "r", allowed = "x", denied = "y" }
}

run "valid_intent_plans" {
  command = plan
}

run "group_outside_scope_is_rejected" {
  command = plan
  variables {
    groups = { lab-admins = "a", lab-team = "t", prod-team = "no" }
  }
  expect_failures = [var.groups]
}

run "asset_without_admin_role_is_rejected" {
  command = plan
  variables {
    jira = {
      project = { key = "LABR", name = "LAB Restricted", type = "software", template = "x", lead_account_id = "u", roles = { member = ["lab-team"] } }
    }
  }
  expect_failures = [var.jira]
}

run "role_outside_standard_is_rejected" {
  command = plan
  variables {
    jira = {
      project = { key = "LABR", name = "LAB Restricted", type = "software", template = "x", lead_account_id = "u", roles = { admin = ["lab-admins"], auditor = ["lab-team"] } }
    }
  }
  expect_failures = [var.jira]
}

run "undeclared_group_bound_to_role_is_rejected" {
  command = plan
  variables {
    jira = {
      project = { key = "LABR", name = "LAB Restricted", type = "software", template = "x", lead_account_id = "u", roles = { admin = ["lab-admins"], member = ["finance-all"] } }
    }
  }
  expect_failures = [var.jira]
}

run "undeclared_group_in_space_audience_is_rejected" {
  command = plan
  variables {
    confluence = { space = { key = "LABP", name = "LAB Private", audience_groups = ["lab-team", "finance-all"] } }
  }
  expect_failures = [var.confluence]
}

run "non_internal_classification_is_rejected" {
  command = plan
  variables {
    governance = { business_authority = "BA-LAB-001", classification = "Confidential", standard = "restricted-collab-v1", authority_records = [] }
  }
  expect_failures = [var.governance]
}

run "unknown_standard_file_is_rejected" {
  command = plan
  variables {
    governance = { business_authority = "BA-LAB-001", classification = "Internal", standard = "no-such-standard-v9", authority_records = [] }
  }
  expect_failures = [var.governance]
}

run "project_type_outside_standard_is_rejected" {
  command = plan
  variables {
    jira = {
      project = { key = "LABR", name = "LAB Restricted", type = "service_desk", template = "x", lead_account_id = "u", roles = { admin = ["lab-admins"] } }
    }
  }
  expect_failures = [var.jira]
}

run "unversioned_standard_is_rejected" {
  command = plan
  variables {
    governance = { business_authority = "BA-LAB-001", classification = "Internal", standard = "restricted-collab", authority_records = [] }
  }
  expect_failures = [var.governance]
}

run "same_person_as_admin_and_reviewer_is_rejected" {
  command = plan
  variables {
    identities = { admin = "a", reviewer = "a", allowed = "x", denied = "y" }
  }
  expect_failures = [var.identities]
}
