# Explanation: Automated Updates

This document explains how dependency updates are automated using Renovate, and how the pre-commit hook ensures manifests stay in sync when update PRs are merged.

---

## What Renovate Does

[Renovate](https://docs.renovatebot.com/) is a bot that scans the repository for dependency version references and opens pull requests to bump them. It runs on a schedule and covers:

- Container image tags in Kubernetes manifests (`deployment.yaml`, `kustomization.yaml`)
- Helm chart versions in `sources/chart.yaml` files
- Tool versions in `.mise/config.toml`
- Pre-commit hook versions in `.pre-commit-config.yaml`

When Renovate finds a new version, it opens a PR with a branch named `renovate/<package>-<version>`. The PR title follows the conventional commit format set in `renovate.json`.

---

## Configuration Overview

The Renovate configuration lives in `renovate.json`. Key settings:

### Commit Format

```json
"semanticCommits": "enabled",
"commitBody": "{{#if isPR}}{{/if}}"
```

Commits use the conventional commit format, matching the style enforced by commitlint.

### Auto-merge Rules

Renovate is configured to auto-merge specific categories of updates without manual review:

| Category | Scope | Schedule | Condition |
| -------- | ----- | -------- | --------- |
| Markdown files | `docs` | Anytime | Minor/patch only |
| Dev tools (mise, pre-commit) | `tools` | Fridays | Minor/patch only |

Major version updates require dashboard approval before Renovate opens a PR.

### Custom Managers

Renovate uses a regex-based custom manager to detect container image versions in the Kubernetes manifests:

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "datasourceTemplate": "docker",
      "fileMatch": ["deployment.yaml", "kustomization.yaml"]
    }
  ]
}
```

This allows Renovate to detect image tag bumps like `ghcr.io/home-assistant/home-assistant:2026.6.4` and open PRs with the next release.

---

## Example: Home Assistant Version Bumps

The commit history shows a clear pattern of automated updates:

```text
chore(homeassistant): bump from 2026.3.4 to 2026.4.3
chore(homeassistant): bump from 2026.2.3 to 2026.3.4
chore(homeassistant): bump from 2026.1.3 to 2026.2.3
chore(homeassistant): bump from 2025.12.0 to 2026.1.3
```

Each commit updates only the image tag in `kubernetes/applications/homeassistant/deployment.yaml`. ArgoCD detects the change on the next poll and performs a rolling update of the Home Assistant pod.

---

## How Manifests Stay in Sync on Update PRs

When Renovate bumps a Helm chart version (e.g., ArgoCD), it modifies `kubernetes/bootstrap/argo-cd/sources/chart.yaml`. This triggers the `render-manifests` pre-commit hook:

```yaml
# .pre-commit-config.yaml
- id: render-manifests
  files: 'kubernetes/**/sources/.*\.yaml'
  entry: mise run manifests:render
```

The hook fires when `sources/*.yaml` files are staged and re-renders the manifests before the commit is finalised. This means the Renovate PR automatically includes both the chart version bump and the updated rendered manifests in the same commit — no manual re-rendering step is needed.

---

## What Renovate Does NOT Update

- Sealed Secrets encrypted blobs — these are not version-tagged
- Ansible playbook logic
- YAML linting rules

---

## Reviewing Renovate PRs

For updates that do not auto-merge (application image updates, major version bumps), Renovate opens a PR for manual review. The PR description includes:

- The old and new versions
- A link to the changelog or release notes (where available)
- CI status (YAML lint, manifest check)

After review, merge the PR. ArgoCD automatically applies the update within 3 minutes.
