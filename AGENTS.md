# AGENTS.md - Guidelines for AI Coding Assistants

This repository is a personal infrastructure learning sandbox and configuration archive containing Ansible playbooks, Kubernetes manifests (K3s/ArgoCD), Terraform modules, and tool configurations. Active targets include a Raspberry Pi homelab (`olympus.local`) and local development clusters (`Kind`), extensible to cloud targets.

## Critical Architectural Guidelines

1. **Rendered Manifests Pattern**:
   - Kubernetes applications in `kubernetes/bootstrap/argo-cd/sources/` use Helm charts as source of truth.
   - NEVER manually edit generated files in `kubernetes/**/manifests/` unless modifying template overlays.
   - ALWAYS run `mise run manifests:render` after changing `sources/chart.yaml` or values files to regenerate split manifests.

2. **Sealed Secrets**:
   - Plain Kubernetes Secret objects must NEVER be committed to Git.
   - Use `kubeseal` to create `SealedSecret` manifests before committing secret definitions.

3. **Ansible Role & Terraform Documentation**:
   - Role documentation is located in `docs/reference/ansible-roles/<role-name>/index.md`.
   - Terraform module documentation is located in `docs/reference/terraform-modules/<module-name>/index.md`.
   - When modifying Ansible roles or Terraform modules, run `mise run doc:generate` to refresh auto-generated doc sections between injection markers (`<!-- BEGIN_ANSIBLE_DOCS -->` / `<!-- BEGIN_TF_DOCS -->`).

4. **Tooling & Task Management**:
   - Use `mise` (`.mise/config.toml`) for tool versioning.
   - Common tasks are located under `.mise/tasks/`.

5. **Commit Message Format**:
   - Follow Conventional Commits format (`feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`).

6. **Pre-Commit Validation**:
   - Run `pre-commit run --all-files` before submitting changes to verify linting, formatting, typos, and manifest checks.
