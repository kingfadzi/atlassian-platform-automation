# Test root: declares only the intent variables so `terraform test` proves the structural
# rules without providers, credentials or a tenant. Run: terraform -chdir=tests/intent test
terraform {
  required_version = ">= 1.9"
}
