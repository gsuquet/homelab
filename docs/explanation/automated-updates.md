# Automated updates

Each dependency of the repository has an exact version. This includes the tools, the pre-commit hooks, the GitHub Actions, the Terraform providers, the Helm charts and the container images. An exact version makes each run repeatable, but it does not change by itself. [Renovate](https://docs.renovatebot.com/) opens the PRs that keep these versions current. This page tells why the updates have their shape. It also tells why only a small set of them merges without a person. The exact settings are in [Renovate settings](../reference/renovate-settings.md).

## Why each version is pinned

A range, for example `^1.2`, lets a new release enter the repository with no change in Git. A run today and a run next week can then use different code. When a run fails, nothing in Git shows the cause.

Thus each version is exact. The GitHub Actions and the pre-commit hooks use a commit SHA, because a tag can move to a different commit. A comment next to the SHA keeps the readable version. The images use a digest for the same reason. The lock files hold the checksums of the tools and the providers. Each change of a version is then a commit, and a revert of that commit restores the earlier version.

The cost is many update PRs. Renovate makes them, so that a person does not have to watch each release.

## Why a release waits three days

A new release can be broken, or it can contain malicious code. Such a release is often withdrawn or reported in the first days. Thus Renovate proposes a release only when it is three days old.

For a security fix, the known weakness is a larger risk than a new release. Thus `renovate.json` lets a vulnerability PR skip the wait and the schedule. Renovate finds these fixes through the Dependabot alerts of GitHub. The Dependabot alerts of this repository are off, so a security fix comes with the normal updates, after the wait. Refer to [Renovate settings](../reference/renovate-settings.md#vulnerability-alerts).

## Why the PRs come once a week

Renovate opens its PRs on Monday morning, in groups. The dev tools come in one PR, and the Terraform providers in one PR. A weekly batch is easier to review than a flow of single PRs during the week. The limits on the number of open PRs and of new PRs each hour keep a large batch small enough to review.

## Why only the dev tools merge by themselves

A person merges each PR. Refer to [How we work](how-we-work.md). The `dev tools` group is the only exception. It holds the minor, patch and digest updates of the tools, the pre-commit hooks and the GitHub Actions.

These updates are frequent and low in risk. The tools run on a laptop and in CI. They do not reach an instance. When a tool update breaks something, the checks of the PR fail, and the PR does not merge. A manual merge of each such PR gives little more safety, and it costs time each week.

Renovate merges these PRs itself, after the checks of the branch pass. It does not use the auto-merge of GitHub. The auto-merge of GitHub waits only for the required status checks of `main`, and the ruleset on `main` has none. Thus it could merge a PR while a check fails.

A compromised tool can still reach `main` after the checks pass. The three-day wait makes this risk smaller.

## Why the other updates merge by hand

The Terraform providers, the Helm charts and the container images reach the instances. A bad update there can break the homelab or a cloud instance, and the checks of a PR do not run the instances. Thus a person reviews and merges them.

The lock file maintenance also merges by hand. One setting covers all the lock files, and some of them reach the instances, for example the Terraform lock files and the `Chart.lock` of Argo CD.

A major update can change the behavior of a dependency. Renovate opens its PR only after an approval on the Dependency Dashboard, so that a person decides first.

## Why chart PRs need a render

The repository commits the rendered manifests of each Helm chart. Refer to [Render the manifests](../how-to/render-manifests.md). `renovate.json` has no task that runs after an update, so Renovate does not run `mise run manifests:render`. Thus a Renovate PR that changes a `Chart.yaml` does not contain the new rendered manifests, and the `Validate Kubernetes Manifests` check fails. A person or an agent runs the render on the PR branch.

## Related pages

- [Renovate settings](../reference/renovate-settings.md)
- [Render the manifests](../how-to/render-manifests.md)
- [How we work](how-we-work.md)
