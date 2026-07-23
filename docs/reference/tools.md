# Reference: Tools

All project tools and their versions are pinned in `.mise/config.toml`. Run `mise install` from the repository root to install them all.

---

## Tool Versions

| Tool | Version | Purpose |
| ---- | ------- | ------- |
| `cilium-cli` | 0.19.5 | Cilium CNI CLI tool |
| `cilium-hubble` | 1.19.4 | Hubble observability CLI for Cilium |
| `git-cliff` | 2.8.0 | Conventional commit changelog generator |
| `github-cli` | 2.96.0 | GitHub CLI (`gh`) for PRs and repo management |
| `gitleaks` | 8.30.1 | SAST secret scanner |
| `helm` | 4.2.3 | Render Kubernetes Helm charts to plain YAML |
| `kyverno` | 1.18.1 | Kubernetes policy engine CLI |
| `pre-commit` | 4.6.0 | Run Git hooks for linting, secret scanning, and manifest rendering |
| `python` | 3.14.6 | Runtime for Ansible and python utilities |
| `terraform` | 1.15.8 | Infrastructure provisioning CLI |
| `terraform-docs` | 0.24.0 | Auto-generate documentation for Terraform modules |
| `tflint` | 0.63.1 | Linter for Terraform code |
| `trivy` | 0.72.0 | Security vulnerability scanner for containers and K8s |
| `typos` | 1.48.0 | Source code spell checker |
| `yq` | 4.53.3 | YAML processor (used in render/split/check scripts) |
| `Ansible` | 11.4.0 | Provision servers via playbooks (pip managed) |

Ansible is installed as a Python package (via pip, managed by mise). The version is set in `.mise/config.toml` as an environment variable:

```toml
[env]
ANSIBLE_VERSION = "11.4.0"
ANSIBLE_CREATOR_VERSION = "25.3.1"
```

---

## Tool Descriptions

### mise

**Purpose**: Manages all tool versions. Replaces `asdf`, `nvm`, `pyenv`, etc. with a single tool.

**Install**:

```bash
curl https://mise.run | sh
```

**Usage**:

```bash
mise install          # Install all tools pinned in .mise/config.toml
mise run <task>       # Run a task defined in .mise/tasks/
```

**Config file**: `.mise/config.toml`

---

### Helm

**Version**: 4.2.3
**Purpose**: Renders Helm charts from `kubernetes/bootstrap/argo-cd/sources/` to plain YAML manifests.

Used by `mise run manifests:render` to produce the committed manifests. Not used at cluster sync time — ArgoCD reads the pre-rendered YAML directly.

---

### Ansible

**Version**: 11.4.0
**Purpose**: Provisions the server — installs K3s, hardens the OS, and bootstraps ArgoCD.

**Config file**: `ansible/ansible.cfg`
**Inventory**: `ansible/inventory/hosts.yml`

---

### pre-commit

**Version**: 4.6.0
**Purpose**: Runs Git hooks defined in `.pre-commit-config.yaml` before each commit.

**Install hooks**:

```bash
pre-commit install
```

---

### terraform-docs

**Version**: 0.24.0
**Purpose**: Auto-generates Terraform module documentation. Used by `mise run doc:generate`.

---

### git-cliff

**Version**: 2.8.0
**Purpose**: Generates `CHANGELOG.md` from conventional git commits. Used by `mise run changelog:generate`.
