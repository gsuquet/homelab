# Label a GitOps component

This guide shows how to give a GitOps component and its Namespace the required labels, and how to make it pass the label checks.

Use this guide when one of these occurs:

- You add a component to `gitops/infrastructure/` or `gitops/apps/`.
- `mise run lint:policy` prints a `K1` to `K15` message for the files of a component.

The guide uses `<component>` for the name of the component, and `<namespace>` for its `namespace` in `gitops/clusters/<cluster>/cluster.yaml`.

## Give the component a tenant

1. Find the group of the component in `gitops/clusters/<cluster>/cluster.yaml`: `infrastructure` or `apps`.
2. If the group is `infrastructure`, the tenant is `platform`. Go to [Label the Namespace](#label-the-namespace).
3. If the group is `apps`, add the component to `components` in `policy/data/labels.yaml`:

   ```yaml
   components:
     <component>:
       tenant: <tenant>
   ```

   Use lowercase letters, digits and `-` in `<tenant>`. Do not use `platform`.

## Label the Namespace

1. Open `gitops/<group>/<component>/sources/templates/namespace.yaml`.
2. Set these labels and this annotation:

   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: {{ .Release.Namespace }}
     labels:
       pod-security.kubernetes.io/enforce: restricted
       pod-security.kubernetes.io/audit: restricted
       pod-security.kubernetes.io/warn: restricted
       tenant.infra.gsuquet.com/name: <tenant>
       ownership.infra.gsuquet.com/owner: gsuquet
       app.kubernetes.io/name: {{ .Chart.Name }}
       app.kubernetes.io/instance: {{ .Release.Name }}
       app.kubernetes.io/managed-by: {{ .Release.Service }}
     annotations:
       argocd.argoproj.io/sync-wave: "-2"
   ```

   `.Release.Namespace` is the namespace of the component in `cluster.yaml`. `.Release.Name` is the component name.

3. Set `<tenant>` to `platform` for an `infrastructure` component, or to the tenant of the component in `policy/data/labels.yaml`.
4. For an `apps` component, use the Pod Security level `restricted` or `baseline`.

## Label the other objects

1. In each other template of `sources/templates/`, set these labels in `metadata.labels`:

   ```yaml
   app.kubernetes.io/name: {{ .Chart.Name }}
   app.kubernetes.io/instance: {{ .Release.Name }}
   app.kubernetes.io/managed-by: {{ .Release.Service }}
   ```

2. In the pod template of each workload, set these labels in `spec.template.metadata.labels`:

   ```yaml
   app.kubernetes.io/name: {{ .Chart.Name }}
   app.kubernetes.io/instance: {{ .Release.Name }}
   app.kubernetes.io/part-of: <component>
   ```

3. In a selector, use only `app.kubernetes.io/name` and `app.kubernetes.io/instance`. Do not use `app.kubernetes.io/version` or `helm.sh/chart`.
4. Give each key that you add a prefix. Use only the keys of the repository that `policy/data/labels.yaml` defines.

Do not put secrets, credentials or personal data in a label or an annotation. Each reader of the cluster can see them.

## Check the labels

1. Render the manifests:

   ```bash
   mise run manifests:render
   ```

2. Add the new files to the Git index. The checks read only the files that Git tracks:

   ```bash
   git add gitops/ policy/data/labels.yaml
   ```

3. Run the checks:

   ```bash
   mise run lint:policy
   ```

4. Find the messages of the component:

   ```bash
   mise run lint:policy 2>&1 | grep "rendered/<component>/"
   ```

5. Correct each `FAIL` line. Each message starts with the ID of its check, for example:

   ```text
   FAIL - Combined - kubernetes - gitops/clusters/kind-local/rendered/demo/namespace-demo.yaml: K4: Namespace "demo", metadata: the value home of the key "tenant.infra.gsuquet.com/name" is not permitted by data.labels
   ```

   This message tells that `policy/data/labels.yaml` has no tenant `home` for the component `demo`.

6. Correct each `WARN` line of the component. A `K5` or `K6` warning shows a missing required label. A `K3w` or `K7` warning comes from an upstream chart. If the chart has a value for its labels, set the label there.
7. Run `mise run lint` before you open a pull request.

For the rule of each check, refer to [Labels and annotations (reference)](../reference/labels-and-annotations.md#checks).

## Related pages

- [Labels and annotations (reference)](../reference/labels-and-annotations.md)
- [Labels and annotations (explanation)](../explanation/labels-and-annotations.md)
- [Add a GitOps component](add-gitops-component.md)
