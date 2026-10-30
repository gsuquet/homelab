# Explanation: Automated Updates

This document tells how Renovate keeps dependencies up to date, and which updates merge without a human review.

---

## What Renovate updates

[Renovate](https://docs.renovatebot.com/) scans the repository and opens pull requests (PRs) to update dependencies. The configuration is in `renovate.json`. Renovate updates:

| Dependency | Location | Manager |
| --- | --- | --- |
| Tools | `.mise/config.toml` | `mise` |
| Pre-commit hooks (commit SHAs) | `.pre-commit-config.yaml` | `pre-commit` |
| GitHub Actions (commit SHAs) | `.github/workflows/*.yml` | `github-actions` |
| Terraform providers and lock files | `modules/**`, `instances/**` | `terraform` |
| Helm chart dependencies | `kubernetes/**/sources/Chart.yaml` | `helmv3` |
| Container images (tag and digest) | `kubernetes/applications/**`, `kubernetes/system/**` | custom regex |
| Versions with a `# renovate:` comment | any YAML, TOML, Terraform or shell file | custom regex |

Renovate does not update `ansible/`. Ansible will be removed.

---

## Pinning

All dependencies are pinned:

- Exact versions (`rangeStrategy: pin`).
- Container images with a digest.
- GitHub Actions and pre-commit hooks with a commit SHA. A comment keeps the readable version.
- Terraform lock files for all platforms. Run `mise run tf:lock` to refresh them.
- Tool checksums in `.mise/mise.lock`.

A new release must be 3 days old before Renovate proposes it (`minimumReleaseAge`). Security fixes do not wait.

---

## Schedule

Renovate opens PRs on Monday before 07:00. Security fixes open at any time. Lock file maintenance runs on the same schedule.

---

## Automatic merge

| Updates | Automatic merge | Condition |
| --- | --- | --- |
| Dev tools: mise, pre-commit, GitHub Actions (minor, patch, digest) | Yes, one grouped PR | All checks pass |
| Lock file maintenance | Yes | All checks pass |
| Terraform providers | No | Human review |
| Helm charts and container images | No | Human review |
| Major updates | No | Approval on the Dependency Dashboard, then human review |

Helm charts and images reach the homelab. They will merge automatically after the Kind tests exist (Phase 4 of the plan). After that, a minor or patch update merges when all checks and Kind tests pass.

---

## Rendered manifests on update PRs

Renovate cannot run commands after an update on the hosted app. When Renovate changes a `sources/Chart.yaml`, the rendered manifests are not updated in the same PR. The `Validate Kubernetes Manifests` workflow then fails. Until Phase 4 adds an automatic render step, run this on the PR branch:

```bash
mise run manifests:render
```

Commit and push the result.
