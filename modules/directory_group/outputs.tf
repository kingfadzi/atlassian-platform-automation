output "id" {
  description = "Atlassian group id discovered by name search."
  value       = restapi_object.group.id
}
output "name" { value = var.name }
