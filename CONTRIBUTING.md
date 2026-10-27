# Contributing

This repository has one owner. People and coding agents (Claude Code, Codex and Antigravity) make the changes. Agents also read [AGENTS.md](AGENTS.md).

## Set up the environment

```bash
git clone https://github.com/gsuquet/homelab.git
cd homelab
mise install
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg
```

`.mise/config.toml` pins each tool to an exact version, and `.mise/mise.lock` holds the checksums.

## Make a change

1. Create a branch from `main`.
2. Make the change.
3. Run `mise run lint`. Correct each problem that it shows.
4. Commit with a [Conventional Commits](https://www.conventionalcommits.org/) message, for example `fix(cilium): set the API server port`.
5. Open a pull request (PR). Fill in the PR template.

## Checks

The standards are checks, not only text. The `Lint` workflow and the pre-commit hooks run the same tasks.

| Check | Task | Reference |
| --- | --- | --- |
| Terraform format and TFLint | `mise run lint:terraform` | [Mise tasks](docs/reference/mise-tasks.md) |
| Conftest policies | `mise run lint:policy` | [Policies](docs/reference/policies.md) |
| GitHub Actions workflows | `mise run lint:actions` | [Mise tasks](docs/reference/mise-tasks.md) |
| Shell scripts | `mise run lint:shell` | [Mise tasks](docs/reference/mise-tasks.md) |
| Documentation language | `mise run lint:docs` | [Writing rules](docs/reference/writing-rules.md) |
| `module.yaml` and `instance.yaml` | `mise run schemas:check` | [Schemas](docs/reference/schemas.md) |

When you add a rule, add a check for it in the same PR.

## Specific changes

| Change | Also do this |
| --- | --- |
| A Helm chart or values in `kubernetes/**/sources/` | Run `mise run manifests:render`. |
| A Terraform module | Run `mise run doc:generate`. |
| A Terraform provider version | Run `mise run tf:lock`. |
| A tool version in `.mise/config.toml` | Run `mise lock`. |
| A new module | Copy `modules/_template/`. Read its `README.md`. |

## Review

A different agent or the owner reviews each PR. The owner approves each change to the homelab, the modules, CI and the standards. `.github/CODEOWNERS` lists these paths. Refer to "Review policy" in [AGENTS.md](AGENTS.md).

## Code of conduct

Obey the [Code of Conduct](CODE_OF_CONDUCT.md).
