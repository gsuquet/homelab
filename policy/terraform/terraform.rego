# Repository rules for Terraform code.
# Input: conftest --combine --parser hcl2, so each item is {"path": ..., "contents": ...}.
package terraform

exact_version := `^[0-9]+\.[0-9]+\.[0-9]+$`

is_module(path) if startswith(path, "modules/")

is_module(path) if contains(path, "/modules/")

# Modules receive providers from the root module. A provider block makes a
# module impossible to reuse with another provider configuration.
deny contains msg if {
	some file in input
	is_module(file.path)
	some name, _ in file.contents.provider
	msg := sprintf("%s: provider %q is configured in a module; configure providers in the root module only", [file.path, name])
}

# Every provider version is pinned to one exact version. The lock file then
# pins the checksums.
deny contains msg if {
	some file in input
	some block in file.contents.terraform
	some providers in block.required_providers
	some name, provider in providers
	not regex.match(exact_version, object.get(provider, "version", ""))
	msg := sprintf("%s: provider %q must use an exact version (x.y.z), got %q", [file.path, name, object.get(provider, "version", "")])
}

# Every provider declares its source address.
deny contains msg if {
	some file in input
	some block in file.contents.terraform
	some providers in block.required_providers
	some name, provider in providers
	not provider.source
	msg := sprintf("%s: provider %q must declare a source", [file.path, name])
}
