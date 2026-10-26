# Repository rules for Kubernetes manifests.
# Input: conftest --combine, so each item is {"path": ..., "contents": ...}.
package kubernetes

# Rendered output comes from a pinned chart; hand-written manifests are pinned here.
is_rendered(path) if contains(path, "/manifests/")

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
