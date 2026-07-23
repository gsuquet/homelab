# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability within this repository or homelab deployment, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please email vulnerability details directly to:

- **Email**: `gabriel.suquet.pro@proton.me`

### What to Include in Your Report

- Summary of the vulnerability and potential impact.
- Step-by-step instructions or proof-of-concept script to reproduce the issue.
- Recommended fixes or mitigations, if known.

### Response Timeline

- **Acknowledgement**: Within 48 hours.
- **Assessment & Fix**: Best effort fix released within 7-14 days depending on severity.

## Security Practices in This Repository

- **Secrets Management**: Sealed Secrets (RSA encrypted) for GitOps secrets.
- **Host Security**: SSH password authentication disabled, UFW firewall rules enforced via Ansible (`os_hardening`).
- **Dependency Scanning**: Gitleaks secret detection, Trivy vulnerability scanning, Renovate automated dependency updates.
