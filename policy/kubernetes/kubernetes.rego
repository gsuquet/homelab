# Repository rules for Kubernetes manifests.
# Input: conftest --combine, so each item is {"path": ..., "contents": ...}.
package kubernetes

# Rendered output comes from a pinned chart; hand-written manifests are pinned here.
is_rendered(path) if contains(path, "/manifests/")

is_rendered(path) if contains(path, "/rendered/")

# Workload kinds and the location of their pod spec.
pod_spec(obj) := obj.spec.template.spec if obj.kind in {"Deployment", "StatefulSet", "DaemonSet", "Job", "ReplicaSet"}

pod_spec(obj) := obj.spec.jobTemplate.spec.template.spec if obj.kind == "CronJob"

pod_spec(obj) := obj.spec if obj.kind == "Pod"

containers(spec) := array.concat(object.get(spec, "initContainers", []), object.get(spec, "containers", []))

images contains [file.path, c.image] if {
	some file in input
	spec := pod_spec(file.contents)
	some c in containers(spec)
}

# The image name without its digest.
image_ref(image) := split(image, "@")[0]

has_tag(image) if {
	ref := image_ref(image)
	parts := split(ref, "/")
	contains(parts[count(parts) - 1], ":")
}

tag(image) := t if {
	ref := image_ref(image)
	parts := split(ref, "/")
	t := split(parts[count(parts) - 1], ":")[1]
}

deny contains msg if {
	some [path, image] in images
	not has_tag(image)
	msg := sprintf("%s: image %q must have an explicit tag", [path, image])
}

deny contains msg if {
	some [path, image] in images
	tag(image) == "latest"
	msg := sprintf("%s: image %q must not use the latest tag", [path, image])
}

deny contains msg if {
	some [path, image] in images
	not is_rendered(path)
	not regex.match(`@sha256:[a-f0-9]{64}$`, image)
	msg := sprintf("%s: image %q must be pinned with a sha256 digest", [path, image])
}

# A branch can set gitops.targetRevision to test itself on Kind. main must sync main.
deny contains msg if {
	some file in input
	startswith(file.path, "gitops/")
	file.contents.kind == "Application"
	revision := file.contents.spec.source.targetRevision
	revision != "main"
	msg := sprintf("%s: the Application syncs %q, not main. Set gitops.targetRevision back to main.", [file.path, revision])
}

# Each GitOps component ships its own Namespace, with the Pod Security labels.
pss_modes := ["enforce", "audit", "warn"]

pss_levels := {"privileged", "baseline", "restricted"}

deny contains msg if {
	some file in input
	startswith(file.path, "gitops/")
	file.contents.kind == "Namespace"
	some mode in pss_modes
	level := object.get(object.get(file.contents.metadata, "labels", {}), sprintf("pod-security.kubernetes.io/%s", [mode]), "")
	not level in pss_levels
	msg := sprintf("%s: the Namespace must have the label pod-security.kubernetes.io/%s set to privileged, baseline or restricted", [file.path, mode])
}

# Sync waves: -2 Namespace, -1 CRDs, 0 the rest, 1 and more the Applications.
expected_wave := {"Namespace": "-2", "CustomResourceDefinition": "-1"}

deny contains msg if {
	some file in input
	startswith(file.path, "gitops/")
	wave := expected_wave[file.contents.kind]
	object.get(object.get(file.contents.metadata, "annotations", {}), "argocd.argoproj.io/sync-wave", "") != wave
	msg := sprintf("%s: a %s must have the annotation argocd.argoproj.io/sync-wave: %q", [file.path, file.contents.kind, wave])
}

# The namespace of a component comes from Git, with its labels. Argo CD must not create it.
deny contains msg if {
	some file in input
	startswith(file.path, "gitops/")
	file.contents.kind == "Application"
	some option in object.get(file.contents.spec, ["syncPolicy", "syncOptions"], [])
	option == "CreateNamespace=true"
	msg := sprintf("%s: do not use CreateNamespace=true. Each component ships its own Namespace.", [file.path])
}

# When a component leaves cluster.yaml, Argo CD deletes its Application. The
# resources of the component must stay: a deleted Application must not delete them.
deny contains msg if {
	some file in input
	startswith(file.path, "gitops/")
	file.contents.kind == "Application"
	some finalizer in object.get(file.contents.metadata, "finalizers", [])
	startswith(finalizer, "resources-finalizer.argocd.argoproj.io")
	msg := sprintf("%s: remove the finalizer %s. A deleted Application must not delete the resources of the component.", [file.path, finalizer])
}

# Git must not hold plain secret values: the data of a Secret is only base64.
# Allowed: a Secret with no data (for example argocd-secret, which argocd-server
# fills), and a SOPS-encrypted Secret. This is a guard against accidents, not a
# security control: a review catches the rest.
secret_fields := ["data", "stringData"]

# The documents of a file: conftest gives a multi-document file as an array.
documents(contents) := contents if is_array(contents)

documents(contents) := [contents] if is_object(contents)

# A List (for example kubectl get -o yaml) holds its resources in items.
# Nested Lists are not walked.
resources(doc) := object.get(doc, "items", []) if doc.kind == "List"

resources(doc) := [doc] if not doc.kind == "List"

secrets contains [file.path, obj] if {
	some file in input
	some doc in documents(file.contents)
	some obj in resources(doc)
	obj.kind == "Secret"
}

# A top-level sops object with a version, and each value as ENC[AES256_GCM,...].
# TODO(sops task): verify the format against real sops output.
sops_encrypted(obj) if {
	is_object(obj.sops)
	count(obj.sops) > 0
	is_string(obj.sops.version)
	every field in secret_fields {
		every value in object.get(obj, field, {}) {
			is_string(value)
			startswith(value, "ENC[AES256_GCM,")
		}
	}
}

deny contains msg if {
	some [path, obj] in secrets
	some field in secret_fields
	count(object.get(obj, field, {})) > 0
	not sops_encrypted(obj)
	name := object.get(obj, ["metadata", "name"], "")
	msg := sprintf("%s: the Secret %q has values in %s that are not SOPS-encrypted. Remove %s, or encrypt it with SOPS.", [path, name, field, field])
}
