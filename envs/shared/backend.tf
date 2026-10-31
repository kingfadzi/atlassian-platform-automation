# GitLab-managed state, one state per stage. Address, lock and auth are injected by the
# pipeline (TF_HTTP_* variables), so nothing environment-specific lives in code.
# `make try` drops a backend_override.tf next to this file to use local state instead.
terraform {
  backend "http" {}
}
