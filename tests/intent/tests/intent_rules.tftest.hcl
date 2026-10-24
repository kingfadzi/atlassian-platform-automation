# Structural rules of the inputs, proven without any tenant or provider.
# Run with: terraform -chdir=tests/intent test

variables {
  tenant     = { org_id = "o", directory_id = "d", site_url = "https://lab.atlassian.net", group_pattern = "^lab-" }
  foundation = { domains = [], product_access_groups = [], banner_contains = "governed" }
}

run "valid_inputs_plan" {
  command = plan
}

run "plain_http_site_is_rejected" {
  command = plan
  variables {
    tenant = { org_id = "o", directory_id = "d", site_url = "http://lab.example.net", group_pattern = "^lab-" }
  }
  expect_failures = [var.tenant]
}

run "invalid_group_pattern_is_rejected" {
  command = plan
  variables {
    tenant = { org_id = "o", directory_id = "d", site_url = "https://lab.atlassian.net", group_pattern = "^lab-(" }
  }
  expect_failures = [var.tenant]
}
