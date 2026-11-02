# Contributing

This is my personal repository. I make changes, and coding agents (Claude Code, Codex and Antigravity) make changes. Agents also read [AGENTS.md](AGENTS.md).

## Set up the environment

```bash
git clone https://github.com/gsuquet/homelab.git
cd homelab
mise install
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg
```

`.mise/config.toml` pins each tool to an exact version, and `.mise/mise.lock` holds the checksums.

## How we work

A new subject starts with the docs. An optional spike on `kind-local` answers the open questions first. Then a doc PR adds the explanation, reference and how-to pages of the thing to build, and my merge approves the design. Then the implementation PRs add the code and the tests. A small, reversible change needs no doc-first step.

The full rules are in [How we work (reference)](docs/reference/how-we-work.md). The reasons are in [How we work (explanation)](docs/explanation/how-we-work.md).

## Make a change

1. Create an issue for the task, and add it to the project "Perso".
2. Create a branch from `main`, with the format `<prefix>/<issue number>-<short-title>`, for example `feat/42-sops-age-key`.
3. Make the change. A PR closes one issue and has one subject.
4. Run `mise run lint`. Correct each problem that it shows.
5. Commit with a signed [Conventional Commits](https://www.conventionalcommits.org/) message, for example `fix(cilium): set the API server port`.
6. Open a draft pull request (PR) with `Closes #N` in its description. Fill in the PR template.

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

A different agent reviews each PR, in one round. A second round occurs only after a HIGH finding. A NIT never blocks a PR. I merge each PR with a squash merge. Refer to "Review policy" in [AGENTS.md](AGENTS.md).

## Code of conduct

Obey the [Code of Conduct](CODE_OF_CONDUCT.md).
