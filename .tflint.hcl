# TFLint configuration for every Terraform module and root module.
# The terraform ruleset is bundled with the TFLint version pinned in .mise/config.toml.

config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}
