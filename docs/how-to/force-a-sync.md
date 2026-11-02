# Force a sync

This guide shows how to make Argo CD apply a merged change at once. Argo CD reads Git about every 3 minutes and syncs by itself. Force a sync when you do not want to wait, or when a sync failed and Argo CD does not try it again.

Change the cluster through a pull request first. A sync applies what is on `main`. It does not replace a merge.

## Refresh an Application

A refresh makes Argo CD read Git now. The automated sync then applies the new commit.

```bash
kubectl -n argocd annotate application <application> \
  argocd.argoproj.io/refresh=normal --overwrite
```

`<application>` is the name of the component in `cluster.yaml`, or `argocd`.

If the Application still shows an old revision, use a hard refresh. It also clears the manifest cache of Argo CD:

```bash
kubectl -n argocd annotate application <application> \
  argocd.argoproj.io/refresh=hard --overwrite
```

Argo CD removes the annotation after the refresh.

## Sync a failed Application again

Argo CD tries a failed sync up to 5 times. After that, the automated sync does not try the same revision again.

1. Find the cause of the failure:

   ```bash
   kubectl -n argocd get application <application> \
     -o jsonpath='{.status.operationState.message}'; echo
   ```

2. Fix the cause in Git through a pull request. The new commit starts a new sync.
3. If the cause was outside Git, for example a node that was not available, open the UI and click **Sync** on the Application. Refer to [Open the Argo CD UI](open-argocd-ui.md).

## Related pages

- [GitOps layout](../reference/gitops-layout.md#applications): the sync policy and the retry settings.
- [GitOps with Argo CD](../explanation/gitops-with-argocd.md)
- [Run your first local cluster](../tutorials/run-your-first-local-cluster.md): Argo CD repairs a deleted resource.
- [Instance tasks](../reference/instance-tasks.md#kubeconfig): the kubectl context of a Kind instance.
