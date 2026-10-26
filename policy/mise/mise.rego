# Repository rules for .mise/config.toml.
package mise

# Every tool is pinned to one exact version: no "latest", no prefix such as "1" or "1.2".
deny contains msg if {
	some name, version in input.tools
	not exact(version)
	msg := sprintf("tool %q must be pinned to an exact version, got %v", [name, version])
}

exact_pattern := `^v?[0-9]+(\.[0-9]+){2}([-+.][0-9A-Za-z.]+)?$`

exact(version) if {
	is_string(version)
	regex.match(exact_pattern, version)
}

exact(version) if {
	is_object(version)
	regex.match(exact_pattern, version.version)
}

# The lock file must stay enabled.
deny contains "settings.lockfile must be true" if {
	not input.settings.lockfile == true
}
