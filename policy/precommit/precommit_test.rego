package precommit_test

import data.precommit

sha := "3e8a8703264a2f4a69428a0aa4dcb512790b2c8c"

test_sha_pinned_repo_is_allowed if {
	count(precommit.deny) == 0 with input as {"repos": [{"repo": "https://github.com/x/y", "rev": sha, "hooks": [{"id": "a"}]}]}
}

test_tag_rev_is_denied if {
	count(precommit.deny) == 1 with input as {"repos": [{"repo": "https://github.com/x/y", "rev": "v6.0.0", "hooks": [{"id": "a"}]}]}
}

test_local_repo_is_allowed if {
	count(precommit.deny) == 0 with input as {"repos": [{"repo": "local", "hooks": [{"id": "a"}]}]}
}

test_unpinned_dependency_is_denied if {
	hooks := [{"id": "commitlint", "additional_dependencies": ["@commitlint/config-conventional"]}]
	count(precommit.deny) == 1 with input as {"repos": [{"repo": "https://github.com/x/y", "rev": sha, "hooks": hooks}]}
}

test_pinned_dependencies_are_allowed if {
	hooks := [{"id": "a", "additional_dependencies": ["@commitlint/config-conventional@21.2.4", "requests==2.32.3"]}]
	count(precommit.deny) == 0 with input as {"repos": [{"repo": "https://github.com/x/y", "rev": sha, "hooks": hooks}]}
}
