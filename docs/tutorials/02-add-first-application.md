# Tutorial: Add Your First Application

This tutorial walks you through adding a new self-hosted application to the cluster. You will create the Kubernetes manifests, push them to Git, and watch ArgoCD deploy the app automatically.

We will use a simple example: a notes app called `mynotes`, running a container on port 3000 with persistent storage.

**Time**: ~20 minutes
**Prerequisites**: Completed [Getting Started](01-getting-started.md), `kubectl` configured

---

## How Application Discovery Works

ArgoCD is configured with an ApplicationSet that watches every subdirectory under `kubernetes/applications/`:

```yaml
# kubernetes/bootstrap/argo-cd/applications-applicationset.yaml
generators:
  - git:
      directories:
        - path: kubernetes/applications/*
```

Any directory you create under `kubernetes/applications/` becomes an ArgoCD Application automatically. The application name and namespace both take the directory name.

---

## Step 1: Create the Application Directory

```bash
mkdir -p kubernetes/applications/mynotes
```

All Kubernetes manifests for your app live in this directory.

---

## Step 2: Write the Manifests

### Persistent Volume Claim

Create `kubernetes/applications/mynotes/pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mynotes-data
  namespace: mynotes
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Deployment

Create `kubernetes/applications/mynotes/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mynotes
  namespace: mynotes
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mynotes
  template:
    metadata:
      labels:
        app: mynotes
    spec:
      containers:
        - name: mynotes
          image: ghcr.io/example/mynotes:1.0.0
          ports:
            - containerPort: 3000
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: mynotes-data
```

### Service

Create `kubernetes/applications/mynotes/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mynotes
  namespace: mynotes
spec:
  selector:
    app: mynotes
  ports:
    - port: 3000
      targetPort: 3000
```

---

## Step 3: Commit and Push

Stage and commit the new files:

```bash
git add kubernetes/applications/mynotes/
git commit -m "feat(mynotes): add mynotes application"
git push
```

The pre-commit hook runs automatically before the commit. It checks for `sources/Chart.yaml` files and re-renders any Helm charts — your plain YAML manifests are unaffected and commit immediately.

---

## Step 4: Watch ArgoCD Discover and Deploy

ArgoCD polls the Git repository every 3 minutes. You can trigger an immediate refresh from the CLI:

```bash
kubectl annotate application mynotes -n argocd \
  argocd.argoproj.io/refresh=normal --overwrite
```

Watch the application appear and sync:

```bash
kubectl get application mynotes -n argocd -w
```

You should see the status progress through `OutOfSync` → `Syncing` → `Synced`.

Check that the pod is running:

```bash
kubectl get pods -n mynotes
```

---

## Step 5: Verify the Application

Confirm the deployment is healthy:

```bash
kubectl get deployment mynotes -n mynotes
kubectl get pvc mynotes-data -n mynotes
kubectl get service mynotes -n mynotes
```

To access the app locally, use port-forwarding:

```bash
kubectl port-forward service/mynotes 3000:3000 -n mynotes
```

Then open `http://localhost:3000` in your browser.

---

## What Happened

1. You created three YAML files under `kubernetes/applications/mynotes/`
2. Pushing to Git triggered ArgoCD to detect the new directory
3. The ApplicationSet created a new `Application` resource named `mynotes` in the `argocd` namespace
4. ArgoCD created the `mynotes` namespace, then applied the PVC, Deployment, and Service
5. Kubernetes scheduled the pod and bound the volume

---

## Next Steps

- Add a sealed secret if your app needs credentials: [Manage Secrets](../how-to/manage-secrets.md)
- Expose the app externally via Cloudflare: [Configure Cloudflare](../how-to/configure-cloudflare.md)
- Learn how ArgoCD manages apps: [GitOps with ArgoCD](../explanation/gitops-with-argocd.md)
