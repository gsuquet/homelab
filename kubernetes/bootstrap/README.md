# ArgoCD Self-Management with Rendered Manifests

This directory contains the ArgoCD installation using the **rendered manifest pattern**, which allows ArgoCD to manage itself.

kubectl apply -f kubere

## Directory Structure

```
argo-cd/
├── sources/
│   └── chart.yaml               # Helm chart configuration (source of truth)
├── manifests/
│   ├── kustomization.yaml       # Kustomize overlay combining all manifests
│   ├── argocd-*.yaml            # Individual component manifests
│   ├── crds-*.yaml              # Custom Resource Definitions
│   ├── dex-*.yaml               # Dex authentication service
│   └── redis-*.yaml             # Redis cache
├── kustomization.yaml           # Main kustomization (combines namespace + manifests/)
├── argo-cd-namespace.yaml       # Namespace definition
└── README.md                    # This file
```

## How It Works

1. **Source Definition**: The Helm chart configuration is defined in `sources/chart.yaml`
2. **Local Rendering**: Run `mise run render` to generate manifests from sources
3. **Manifest Splitting**: Manifests are automatically split into individual files per resource
4. **Initial Installation**: The Ansible role applies the rendered manifests via `kubectl apply -k`
5. **Self-Management**: After ArgoCD is running, the self-management Application resource monitors this directory
6. **Ongoing Management**: ArgoCD auto-syncs any changes to the rendered manifests

## Benefits

- **GitOps Native**: All ArgoCD configuration is tracked in Git with full history
- **Reviewable Changes**: Easy to see what changed in individual files
- **Self-Healing**: ArgoCD automatically corrects drift from the desired state
- **Declarative Updates**: Update ArgoCD by modifying `sources/chart.yaml` and committing to Git
- **Transparent**: Each resource type is in its own file for easy understanding
- **Modular**: Kustomize can overlay or patch specific components if needed

## Updating ArgoCD

To update ArgoCD:

1. Modify `sources/chart.yaml` with your desired changes
2. Run `mise run render` to regenerate the manifests and split them:
   ```bash
   mise run render
   # Or do it step by step:
   # bash scripts/render-manifests.sh
   # bash scripts/split-manifests.sh
   # bash scripts/generate-kustomization.sh
   ```
3. Commit the updated files to Git
4. ArgoCD will detect the changes and sync automatically

Or let pre-commit handle it automatically:

```bash
git add sources/chart.yaml
git commit -m "Update ArgoCD configuration"
# pre-commit hook automatically renders and splits manifests
git push
```

## Manifest Organization

The split manifests are organized by component:

- **argocd-application-controller-*** - Application controller components
- **argocd-applicationset-*** - ApplicationSet controller components
- **argocd-configs-*** - Configuration ConfigMaps and Secrets
- **argocd-notifications-*** - Notifications controller components
- **argocd-repo-server-*** - Repository server components
- **argocd-server-*** - ArgoCD server components
- **crds-*** - Custom Resource Definitions
- **dex-*** - Dex authentication service
- **redis-*** - Redis cache components

Each file is named after its resource type and follows the format:
```
<component>-<subcomponent>-<resource-type>.yaml
```

For example:
- `argocd-application-controller-serviceaccount.yaml` - ServiceAccount for application controller
- `argocd-server-deployment.yaml` - Deployment for the server
- `crds-crd-application.yaml` - Application CRD

## Tools Used

- **Helm**: For rendering charts (`scripts/render-manifests.sh`)
- **yq**: For parsing YAML configuration
- **bash scripts**: For splitting manifests (`scripts/split-manifests.sh`)
- **Kustomize**: For combining namespace + individual manifests

## Mise Tasks

```bash
# Render manifests from sources, split them, and generate kustomization
mise run render

# Just split existing manifests and regenerate kustomization
mise run split-manifests

# Check if manifests are up-to-date
mise run check-manifests
```

## References

- [ArgoCD Self-Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#manage-argo-cd-using-argo-cd)
- [Rendered Manifests Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#declarative-setup)
- [Kustomize Documentation](https://kustomize.io/)
