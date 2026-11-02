# Label a GitOps component

This guide shows how to give a GitOps component and its Namespace the required labels, and how to make it pass the label checks.

Use this guide when one of these occurs:

- You add a component to `gitops/infrastructure/` or `gitops/apps/`.
- `mise run lint:policy` prints a `K1` to `K15` message for the files of a component.

The guide uses `<component>` for the name of the component.

## Before you start

- The component has a folder in `gitops/<group>/<component>/sources/` and an entry in `gitops/clusters/<cluster>/cluster.yaml`. Refer to [Add a GitOps component](add-gitops-component.md).
- You ran `mise install`.

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

3. Set `<tenant>` to `platform` for an `infrastructure` component.
4. Set `<tenant>` to the tenant in `policy/data/labels.yaml` for an `apps` component.
5. For an `apps` component, use the Pod Security level `restricted` or `baseline`.

## Label the other objects

1. In each other template of `sources/templates/`, set these labels in `metadata.labels`:

   ```yaml
   app.kubernetes.io/name: {{ .Chart.Name }}
   app.kubernetes.io/instance: {{ .Release.Name }}
   app.kubernetes.io/managed-by: {{ .Release.Service }}
   ```

2. Set these labels in `spec.template.metadata.labels`, or `spec.jobTemplate.spec.template.metadata.labels` for a CronJob:

   ```yaml
   app.kubernetes.io/name: {{ .Chart.Name }}
   app.kubernetes.io/instance: {{ .Release.Name }}
   app.kubernetes.io/part-of: <component>
   ```

3. In a selector, use only `app.kubernetes.io/name` and `app.kubernetes.io/instance`.
4. Give each new key a prefix.
5. Use only the keys of the repository that `policy/data/labels.yaml` defines.
6. Do not put secrets, credentials or personal data in a label or an annotation.

## Check the labels

1. Render the manifests:

   ```bash
   mise run manifests:render
   ```

2. Add the new files to the Git index:

   ```bash
   git add gitops/ policy/data/labels.yaml
   ```

3. Run the checks, and keep the messages of the component:

   ```bash
   mise run lint:policy 2>&1 | grep -e "rendered/<component>/" -e labels.yaml -e cluster.yaml
   ```

4. Correct each `FAIL` line. For example:

   ```text
   FAIL - Combined - kubernetes - gitops/clusters/kind-local/rendered/demo/namespace-demo.yaml: K4: Namespace "demo", metadata: the value home of the key "tenant.infra.gsuquet.com/name" is not permitted by data.labels
   ```

   To correct this message, add the tenant `home` to the entry of `demo` in `policy/data/labels.yaml`.

5. Correct each `K5` or `K6` warning: add the missing label.
6. For a `K3w` or `K7` warning, set the label in the values of the upstream chart, if the chart permits it.
7. Run `mise run lint`.

For the ID after the file path in each message, refer to [Checks](../reference/labels-and-annotations.md#checks).

## Related pages

- [Labels and annotations (reference)](../reference/labels-and-annotations.md)
- [Why the label scheme has its form](../explanation/labels-and-annotations.md)
- [Add a GitOps component](add-gitops-component.md)
