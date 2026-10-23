output "id" { value = restapi_object.scheme.id }
output "grant_ids" { value = { for k, g in restapi_object.grant : k => g.id } }
