# Each key in contract.provides of module.yaml has an output with the same name.
output "example_id" {
  description = "ID of the example resource."
  value       = terraform_data.this.id
}
