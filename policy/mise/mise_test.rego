package mise_test

import data.mise

settings := {"lockfile": true}

test_exact_versions_are_allowed if {
	count(mise.deny) == 0 with input as {"settings": settings, "tools": {"helm": "4.3.1", "pipx:check-jsonschema": "0.38.2", "python": {"version": "3.15.1"}}}
}

test_latest_is_denied if {
	count(mise.deny) == 1 with input as {"settings": settings, "tools": {"helm": "latest"}}
}

test_prefix_version_is_denied if {
	count(mise.deny) == 1 with input as {"settings": settings, "tools": {"python": "3.15"}}
}

test_lockfile_disabled_is_denied if {
	count(mise.deny) == 1 with input as {"settings": {"lockfile": false}, "tools": {"helm": "4.3.1"}}
}
