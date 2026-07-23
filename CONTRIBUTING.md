# Contributing to HomeLab

Thank you for considering contributing to the HomeLab project!

## Getting Started

1. **Fork and Clone**:

   ```bash
   git clone https://github.com/gsuquet/homelab.git
   cd homelab
   ```

2. **Set Up Environment**:

   ```bash
   mise install
   pre-commit install
   ```

## Development Workflow

### 1. Conventional Commits

All commit messages must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat: add homeassistant component`
- `fix: update cloudflare tunnel secret path`
- `docs: update ansible role reference`
- `chore: bump helm chart dependency`

### 2. Kubernetes Manifest Changes

If modifying Helm sources in `kubernetes/**/sources/`:

```bash
mise run manifests:render
```

This renders charts and updates split manifests in Git.

### 3. Documentation Changes

If modifying Ansible roles or Terraform modules:

```bash
mise run doc:generate
```

This updates reference docs in `docs/reference/`.

### 4. Running Checks & Verification

Before pushing or opening a PR, ensure all pre-commit hooks pass:

```bash
pre-commit run --all-files
```

## Code of Conduct

Please adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) in all community interactions.
