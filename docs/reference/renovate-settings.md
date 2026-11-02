# Renovate settings

[Renovate](https://docs.renovatebot.com/) runs as the GitHub App `renovate-gsuquet`. It opens the PRs that update the dependencies of the repository. Its settings are in `renovate.json`. The reasons are in [Automated updates](../explanation/automated-updates.md).

## Base settings

| Setting | Value | Effect |
| --- | --- | --- |
| `extends` | `config:best-practices`, `customManagers:githubActionsVersions`, `helpers:pinGitHubActionDigestsToSemver`, `:enablePreCommit`, `:gitSignOff`, `:rebaseStalePrs`, `:semanticCommits`, `:semanticCommitScope(deps)` | The presets. |
| `rangeStrategy` | `pin` | Each version is exact. |
| `minimumReleaseAge` | `3 days` | A release must be 3 days old before Renovate proposes it. |
| `internalChecksFilter` | `strict` | Renovate opens no branch for a release that is younger than `minimumReleaseAge`. |
| `schedule` | `* 0-6 * * 1` | Renovate opens PRs on Monday, from 00:00 to 06:59 UTC. `timezone` has no value, so the schedule uses UTC. |
| `branchPrefix` | `renovate/` | The prefix of each Renovate branch. |
| `labels` | `renovate` | The label of each Renovate PR. |
| `prConcurrentLimit` | `10` | At most 10 open Renovate PRs. |
| `prHourlyLimit` | `4` | At most 4 new Renovate PRs each hour. |
| `dependencyDashboard` | `true` | Renovate keeps a Dependency Dashboard issue. |
| `commitBodyTable` | `true` | The commit body has a table of the updates. |
| `configMigration` | `true` | Renovate opens a PR when `renovate.json` uses old options. |
| `kubernetes.enabled` | `false` | The `kubernetes` manager is off. A custom manager reads the images. |

## Managers

| Dependency | Files | Manager |
| --- | --- | --- |
| Tools | `.mise/config.toml` | `mise` |
| Pre-commit hooks, pinned to a commit SHA | `.pre-commit-config.yaml` | `pre-commit` |
| GitHub Actions, pinned to a commit SHA | `.github/workflows/*.yml` | `github-actions` |
| Terraform providers and lock files | `*.tf`, `.terraform.lock.hcl` | `terraform` |
| Helm chart dependencies | `Chart.yaml` | `helmv3` |
| Container images, with a tag and a digest | `kubernetes/applications/**`, `kubernetes/system/**` | `custom.regex` |
| Versions with a trailing `# renovate: datasource=<datasource> depName=<name>` comment | `.mise/config.toml`, `*.yaml`, `*.yml`, `*.tf`, `*.sh` | `custom.regex` |

The comment of the second custom manager can also set `versioning=<versioning>`.

## Package rules

| Rule | Match | Settings |
| --- | --- | --- |
| Major updates | `matchUpdateTypes: major` | `dependencyDashboardApproval: true`: the PR opens only after an approval on the Dependency Dashboard. |
| Dev tools | One rule. An update must match all three: one of the files `.mise/config.toml`, `.pre-commit-config.yaml` and `.github/workflows/**`, one of the managers `mise`, `pre-commit`, `github-actions` and `custom.regex`, and one of the update types `minor`, `patch`, `digest`, `pin` and `pinDigest`. | One group, `dev tools`. Automerge. Commit scope `tools`. |
| Terraform providers | `matchManagers: terraform` | One group, `terraform providers`. Commit scope `terraform`. |
| Charts and images | The files `gitops/**` and `kubernetes/**` | Commit scope `kubernetes`. |
| Ansible | Two rules. Each one turns the updates off alone: one for the files `ansible/**`, one for the packages `ansible` and `ansible-creator`. | `enabled: false`: no updates. |
| Lock file maintenance | `matchUpdateTypes: lockFileMaintenance` | Commit scope `lock`. |

The other updates use the commit scope `deps`.

## Automerge

Only the `dev tools` group merges without a person:

- `automerge: true`, `automergeType: pr`.
- `platformAutomerge: false`: Renovate merges the PR itself, through the API, after the checks of its branch pass. It does not use the auto-merge of GitHub ([Renovate: platformAutomerge](https://docs.renovatebot.com/configuration-options/#platformautomerge)).

All the other Renovate PRs merge by hand. This includes the Terraform providers, the charts, the images, the major updates and the lock file maintenance.

## Lock file maintenance

| Setting | Value |
| --- | --- |
| `lockFileMaintenance.enabled` | `true` |
| `lockFileMaintenance.automerge` | `false` |
| `lockFileMaintenance.schedule` | `* 0-6 * * 1` |

## Vulnerability alerts

| Setting | Value | Effect |
| --- | --- | --- |
| `vulnerabilityAlerts.labels` | `renovate`, `security` | The labels of a vulnerability PR. |
| `vulnerabilityAlerts.minimumReleaseAge` | `null` | A security fix does not wait 3 days. |
| `vulnerabilityAlerts.schedule` | `at any time` | A security fix opens at any time. |

These settings take effect only when the Dependency graph and the Dependabot alerts of the repository are on. Renovate reads the vulnerability alerts from GitHub ([Renovate: vulnerabilityAlerts](https://docs.renovatebot.com/configuration-options/#vulnerabilityalerts)). In this repository, the Dependabot alerts are off, so Renovate opens no vulnerability PR.

## Related pages

- [Automated updates](../explanation/automated-updates.md)
- [Render the manifests](../how-to/render-manifests.md)
- [Work rules](how-we-work.md)
- [Tools](tools.md)
