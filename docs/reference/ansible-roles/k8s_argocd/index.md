# Ansible Role: k8s_argocd

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the `k8s_argocd` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
### Tasks Overview

Tasks defined in `tasks/main.yml`:

- Set ArgoCD deployment variables
- Check if ArgoCD is already installed
- Ensure ArgoCD namespace exists
- Copy ArgoCD manifests to remote host
- Copy ArgoCD bootstrap application to remote host
- Apply ArgoCD rendered manifests
- Wait for ArgoCD server deployment to be ready
- Apply ArgoCD bootstrap application (app of apps)
- Clean up temporary ArgoCD files

### Variables & Defaults

*No default variables configured.*
<!-- END_ANSIBLE_DOCS -->
