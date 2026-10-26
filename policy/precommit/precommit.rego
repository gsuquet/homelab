# Repository rules for .pre-commit-config.yaml.
package precommit

# Remote hooks are pinned to a full commit SHA. Local hooks have no rev.
deny contains msg if {
	some repo in input.repos
	not repo.repo in {"local", "meta"}
	not regex.match(`^[a-f0-9]{40}$`, object.get(repo, "rev", ""))
	msg := sprintf("hook repository %q must be pinned to a 40-character commit SHA, got %q", [repo.repo, object.get(repo, "rev", "")])
}

# Extra npm or pip packages are pinned to an exact version.
deny contains msg if {
	some repo in input.repos
	some hook in repo.hooks
	some dep in object.get(hook, "additional_dependencies", [])
	not regex.match(`.+(@|==)[0-9]+\.[0-9]+\.[0-9]+$`, dep)
	msg := sprintf("hook %q: additional dependency %q must be pinned to an exact version", [hook.id, dep])
}
