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

# ---------------------------------------------------------------------------
# Label and annotation keys: checks K1 to K10 and K14 to K17. K11 to K13 (cloud
# labels) come with the first cloud instance. The rules, the allowlists and the required keys
# come from data.labels, in policy/data/labels.yaml. Each message has the ID
# of its check.
#
# The origin of a rendered object is in its file name: manifests:render gives
# the prefix upstream-- to each object from an upstream chart. K1 to K7 read the
# keys of metadata.labels and metadata.annotations, also in pod templates. Only
# K8 reads selectors. The legacy files in kubernetes/ get only K1.

# Without the data file, all the checks below pass in silence.
deny contains msg if {
	not is_object(data.labels)
	msg := "policy/data/labels.yaml is not loaded: run conftest with --data policy/data"
}

# Each key of data.labels that a check reads: [path, type, must not be empty].
# A missing or empty key would make a check pass in silence. The allowlists
# that only permit more can be empty.
labels_data_keys := [
	[["prefix"], "string", true],
	[["platform_tenant"], "string", true],
	[["subgroups"], "object", true],
	[["components"], "object", false],
	[["unstable_keys"], "array", true],
	[["forbidden_sync_options"], "array", true],
	[["apps_pod_security_levels"], "array", true],
	[["required", "namespace", "labels"], "array", true],
	[["required", "pod_template", "labels"], "array", true],
	[["required", "object", "labels"], "array", true],
	[["required", "cloud", "labels"], "array", true],
	[["required", "cloud", "ephemeral_labels"], "array", false],
	[["allowlists", "reserved_prefixes", "keys"], "array", false],
	[["allowlists", "reserved_prefixes", "prefixes"], "array", false],
	[["allowlists", "no_prefix"], "array", false],
	[["allowlists", "custom_keys_upstream"], "array", false],
	[["allowlists", "sync_options_upstream"], "array", false],
	[["allowlists", "pod_security_apps"], "array", false],
	# K16 refuses a privileged container outside these namespaces: an empty list permits none.
	[["allowlists", "pod_security_privileged"], "array", false],
	# K18 refuses a hostPath on /procHost outside these namespaces: an empty list permits none.
	[["allowlists", "host_path_procfs"], "array", false],
	# K15 refuses these namespaces: an empty list refuses none.
	[["allowlists", "reserved_namespaces"], "array", true],
	[["allowlists", "upstream_namespaces"], "array", false],
]

deny contains msg if {
	is_object(data.labels)
	some [path, type, _] in labels_data_keys
	value := object.get(data.labels, path, null)
	type_name(value) != type
	msg := sprintf("policy/data/labels.yaml: labels.%s must have the type %s, not %s", [concat(".", path), type, type_name(value)])
}

deny contains msg if {
	is_object(data.labels)
	some [path, type, true] in labels_data_keys
	value := object.get(data.labels, path, null)
	type_name(value) == type
	count(value) == 0
	msg := sprintf("policy/data/labels.yaml: labels.%s must not be empty", [concat(".", path)])
}

as_object(x) := x if is_object(x)

else := {}

as_array(x) := x if is_array(x)

else := []

# Each Kubernetes object of the input: [path, object]. The metadata files of the
# repository (cluster.yaml, instance.yaml, module.yaml) use the API group
# infra.gsuquet.com and are not Kubernetes objects.
k8s_objects contains [file.path, obj] if {
	some file in input
	some doc in documents(file.contents)
	some obj in resources(doc)
	is_object(obj)
	is_string(obj.kind)
	is_string(obj.apiVersion)
	not startswith(obj.apiVersion, "infra.gsuquet.com/")
}

object_name(obj) := object.get(obj, ["metadata", "name"], "")

is_gitops(path) if startswith(path, "gitops/")

# gitops/clusters/<cluster>/rendered/<component>/<file>: [cluster, component, file].
rendered_parts(path) := [parts[2], parts[4], parts[5]] if {
	parts := split(path, "/")
	count(parts) == 6
	parts[0] == "gitops"
	parts[1] == "clusters"
	parts[3] == "rendered"
}

is_upstream(path) if {
	[_, _, name] := rendered_parts(path)
	startswith(name, "upstream--")
}

is_hand_written(path) if {
	is_gitops(path)
	not is_upstream(path)
}

# The content of each gitops/clusters/<cluster>/cluster.yaml in the input.
cluster_files[parts[2]] := file.contents if {
	some file in input
	parts := split(file.path, "/")
	count(parts) == 4
	parts[0] == "gitops"
	parts[1] == "clusters"
	parts[3] == "cluster.yaml"
	is_object(file.contents)
}

component_groups := ["infrastructure", "apps"]

# [cluster, group, component, namespace] for each component of cluster.yaml.
cluster_components contains [cluster, group, object.get(component, "name", ""), object.get(component, "namespace", "")] if {
	some cluster, content in cluster_files
	some group in component_groups
	some component in as_array(object.get(content, group, []))
	is_object(component)
}

# The component of a rendered object is in <group> of its cluster.yaml.
in_group(path, group) if {
	[cluster, component, _] := rendered_parts(path)
	some entry in cluster_components
	entry[0] == cluster
	entry[1] == group
	entry[2] == component
}

# The tenant of the component of a rendered object (K4, K5).
component_tenant(path) := data.labels.platform_tenant if in_group(path, "infrastructure")

component_tenant(path) := tenant if {
	in_group(path, "apps")
	[_, component, _] := rendered_parts(path)
	tenant := data.labels.components[component].tenant
	tenant != data.labels.platform_tenant
}

workload_kinds := {"Deployment", "StatefulSet", "DaemonSet", "Job", "ReplicaSet"}

# The blocks of metadata of an object: the object, and its pod template. kind is
# the kind that K4 compares with data.labels: Pod for a pod template.
metadata_blocks(obj) := array.concat([{"where": "metadata", "kind": obj.kind, "metadata": as_object(obj.metadata)}], template_blocks(obj))

template_blocks(obj) := [{"where": "pod template", "kind": "Pod", "metadata": as_object(object.get(obj, ["spec", "template", "metadata"], {}))}] if {
	obj.kind in workload_kinds
}

template_blocks(obj) := [
	{"where": "job template", "kind": "Job", "metadata": as_object(object.get(obj, ["spec", "jobTemplate", "metadata"], {}))},
	{"where": "pod template", "kind": "Pod", "metadata": as_object(object.get(obj, ["spec", "jobTemplate", "spec", "template", "metadata"], {}))},
] if {
	obj.kind == "CronJob"
}

template_blocks(obj) := [] if {
	not obj.kind in workload_kinds
	obj.kind != "CronJob"
}

key_fields := {"label": "labels", "annotation": "annotations"}

# Each key of each object: the path, the object, the block, the type, the key and the value.
object_keys contains {"path": path, "obj": obj, "where": block.where, "kind": block.kind, "type": type, "key": key, "value": value} if {
	some [path, obj] in k8s_objects
	some block in metadata_blocks(obj)
	some type, field in key_fields
	some key, value in as_object(object.get(block.metadata, field, {}))
}

subject(e) := sprintf("%s %q, %s", [e.obj.kind, object_name(e.obj), e.where])

# Syntax rules of the Kubernetes labels, annotations and names:
# https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
dns_subdomain := `^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$`

key_name_pattern := `^[A-Za-z0-9]([-A-Za-z0-9_.]*[A-Za-z0-9])?$`

label_value_pattern := `^([A-Za-z0-9]([-A-Za-z0-9_.]*[A-Za-z0-9])?)?$`

# The repository adds: lowercase letters, digits and - only, in the name of its
# keys and in the values of its labels. Thus the cloud form of a key has no
# collision, and the values are valid Google Cloud label values.
repository_name_pattern := `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`

repository_value_pattern := `^([a-z0-9]([-a-z0-9]*[a-z0-9])?)?$`

max_annotation_bytes := 262144

key_prefix(key) := parts[0] if {
	parts := split(key, "/")
	count(parts) == 2
}

key_name(key) := parts[count(parts) - 1] if parts := split(key, "/")

valid_key_name(name) if {
	count(name) <= 63
	regex.match(key_name_pattern, name)
}

valid_key(key) if {
	not contains(key, "/")
	valid_key_name(key)
}

valid_key(key) if {
	prefix := key_prefix(key)
	count(prefix) <= 253
	regex.match(dns_subdomain, prefix)
	valid_key_name(key_name(key))
}

valid_label_value(value) if {
	is_string(value)
	count(value) <= 63
	regex.match(label_value_pattern, value)
}

is_custom_key(key) if key_prefix(key) == data.labels.prefix

is_custom_key(key) if endswith(key_prefix(key), concat("", [".", data.labels.prefix]))

# The sub-group of a custom key. A key with the prefix infra.gsuquet.com alone
# has the empty sub-group, which data.labels does not have.
custom_subgroup(key) := trim_suffix(trim_suffix(key_prefix(key), data.labels.prefix), ".") if is_custom_key(key)

# K1 Syntax: each object in gitops/ and kubernetes/.
deny contains msg if {
	some e in object_keys
	not valid_key(e.key)
	msg := sprintf("%s: K1: %s: the %s key %q is not valid. A key is [<DNS subdomain, max. 253>/]<name, max. 63>.", [e.path, subject(e), e.type, e.key])
}

deny contains msg if {
	some e in object_keys
	e.type == "label"
	not valid_label_value(e.value)
	msg := sprintf("%s: K1: %s: the value %v of the label %q is not valid. A label value is a string of max. 63 letters, digits, -, _ and ., that starts and ends with a letter or a digit.", [e.path, subject(e), e.value, e.key])
}

deny contains msg if {
	some e in object_keys
	e.type == "annotation"
	not is_string(e.value)
	msg := sprintf("%s: K1: %s: the value %v of the annotation %q is not a string. Quote it in YAML.", [e.path, subject(e), e.value, e.key])
}

deny contains msg if {
	some e in object_keys
	is_custom_key(e.key)
	not regex.match(repository_name_pattern, key_name(e.key))
	msg := sprintf("%s: K1: %s: the name of the key %q must use lowercase letters, digits and - only", [e.path, subject(e), e.key])
}

deny contains msg if {
	some e in object_keys
	e.type == "label"
	is_custom_key(e.key)
	is_string(e.value)
	not regex.match(repository_value_pattern, e.value)
	msg := sprintf("%s: K1: %s: the value %q of the label %q must use lowercase letters, digits and - only", [e.path, subject(e), e.value, e.key])
}

deny contains msg if {
	some [path, obj] in k8s_objects
	some block in metadata_blocks(obj)
	annotations := as_object(object.get(block.metadata, "annotations", {}))
	size := sum([n | some key, value in annotations; is_string(value); n := count(key) + count(value)])
	size > max_annotation_bytes
	msg := sprintf("%s: K1: %s %q, %s: the annotations have %d bytes. The maximum is %d.", [path, obj.kind, object_name(obj), block.where, size, max_annotation_bytes])
}

# K2 Reserved prefixes: hand-written objects in gitops/.
reserved_domains := ["kubernetes.io", "k8s.io"]

is_reserved_key(key) if key_prefix(key) in reserved_domains

is_reserved_key(key) if {
	some domain in reserved_domains
	endswith(key_prefix(key), concat("", [".", domain]))
}

reserved_key_allowed(key) if key in data.labels.allowlists.reserved_prefixes.keys

reserved_key_allowed(key) if {
	some prefix in data.labels.allowlists.reserved_prefixes.prefixes
	startswith(key, prefix)
}

deny contains msg if {
	some e in object_keys
	is_hand_written(e.path)
	is_reserved_key(e.key)
	not reserved_key_allowed(e.key)
	msg := sprintf("%s: K2: %s: the key %q has a prefix that Kubernetes reserves, and it is not in data.labels.allowlists.reserved_prefixes", [e.path, subject(e), e.key])
}

# K3 No prefix: hand-written objects in gitops/ (deny). K3w: upstream objects (warn).
no_prefix_key(e) if {
	not contains(e.key, "/")
	not e.key in data.labels.allowlists.no_prefix
}

deny contains msg if {
	some e in object_keys
	is_hand_written(e.path)
	no_prefix_key(e)
	msg := sprintf("%s: K3: %s: the key %q has no prefix. Use <subgroup>.%s/<name>.", [e.path, subject(e), e.key, data.labels.prefix])
}

warn contains msg if {
	some e in object_keys
	is_upstream(e.path)
	no_prefix_key(e)
	msg := sprintf("%s: K3w: %s: the key %q of the upstream chart has no prefix", [e.path, subject(e), e.key])
}

# K4 Custom keys: all objects in gitops/, with an allowlist for upstream exceptions.
k4_allowlisted(e) if {
	is_upstream(e.path)
	[_, component, _] := rendered_parts(e.path)
	some entry in data.labels.allowlists.custom_keys_upstream
	entry == {"component": component, "kind": e.obj.kind, "name": object_name(e.obj), "key": e.key}
}

k4_keys contains e if {
	some e in object_keys
	is_gitops(e.path)
	is_custom_key(e.key)
	not k4_allowlisted(e)
}

key_spec(key) := data.labels.subgroups[custom_subgroup(key)].keys[key_name(key)]

permitted_value(spec, e) if {
	some value in object.get(spec, "values", [])
	value == e.value
}

permitted_value(spec, e) if {
	is_string(e.value)
	regex.match(spec.pattern, e.value)
}

permitted_value(spec, e) if {
	spec.values_from == "tenant"
	e.value == component_tenant(e.path)
}

permitted_value(spec, e) if {
	spec.values_from == "network"
	[_, component, _] := rendered_parts(e.path)
	some value in object.get(data.labels.components, [component, "network", key_name(e.key)], [])
	value == e.value
}

deny contains msg if {
	some e in k4_keys
	not custom_subgroup(e.key) in object.keys(data.labels.subgroups)
	msg := sprintf("%s: K4: %s: the key %q has no sub-group of data.labels. The sub-groups are: %s.", [e.path, subject(e), e.key, concat(", ", sort(object.keys(data.labels.subgroups)))])
}

deny contains msg if {
	some e in k4_keys
	subgroup := custom_subgroup(e.key)
	keys := data.labels.subgroups[subgroup].keys
	not key_name(e.key) in object.keys(keys)
	msg := sprintf("%s: K4: %s: the key %q is not in data.labels. The keys of %s are: %s.", [e.path, subject(e), e.key, subgroup, concat(", ", sort(object.keys(keys)))])
}

deny contains msg if {
	some e in k4_keys
	spec := key_spec(e.key)
	spec.type != e.type
	msg := sprintf("%s: K4: %s: the key %q must be a %s, not a %s", [e.path, subject(e), e.key, spec.type, e.type])
}

deny contains msg if {
	some e in k4_keys
	spec := key_spec(e.key)
	not e.kind in spec.kinds
	msg := sprintf("%s: K4: %s: the key %q is not permitted on a %s. Permitted kinds: %v.", [e.path, subject(e), e.key, e.kind, spec.kinds])
}

deny contains msg if {
	some e in k4_keys
	spec := key_spec(e.key)
	spec.type == e.type
	e.kind in spec.kinds
	not permitted_value(spec, e)
	msg := sprintf("%s: K4: %s: the value %v of the key %q is not permitted by data.labels", [e.path, subject(e), e.value, e.key])
}

# K5 Required keys: each Namespace in gitops/.
# TODO(follow-up PR): change to deny. The argocd Namespace fails it until a
# later PR adds its tenant and ownership labels.
gitops_namespaces contains [path, obj] if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	obj.kind == "Namespace"
}

warn contains msg if {
	some [path, obj] in gitops_namespaces
	some key in data.labels.required.namespace.labels
	not key in object.keys(as_object(object.get(as_object(obj.metadata), "labels", {})))
	msg := sprintf("%s: K5: Namespace %q: the label %q is missing", [path, object_name(obj), key])
}

# The tenant of an apps component is not the platform tenant.
deny contains msg if {
	some component, entry in data.labels.components
	object.get(entry, "tenant", "") == data.labels.platform_tenant
	msg := sprintf("policy/data/labels.yaml: K5: components.%s.tenant must not be %q. It is reserved for the infrastructure components.", [component, data.labels.platform_tenant])
}

# K6 Required keys of workloads: hand-written objects in gitops/.
# K7: upstream objects (warn).
# TODO(follow-up PR): change K6 to deny. The hand-written objects of the argocd
# component fail it until a later PR adds their labels.
required_by_block := {
	"metadata": data.labels.required.object.labels,
	"pod template": data.labels.required.pod_template.labels,
}

missing_app_labels contains [path, obj, block.where, key] if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	some block in metadata_blocks(obj)
	some key in required_by_block[block.where]
	not key in object.keys(as_object(object.get(block.metadata, "labels", {})))
}

warn contains msg if {
	some [path, obj, where, key] in missing_app_labels
	is_hand_written(path)
	msg := sprintf("%s: K6: %s %q, %s: the label %q is missing", [path, obj.kind, object_name(obj), where, key])
}

warn contains msg if {
	some [path, obj, where, key] in missing_app_labels
	is_upstream(path)
	msg := sprintf("%s: K7: %s %q, %s: the label %q of the upstream chart is missing", [path, obj.kind, object_name(obj), where, key])
}

# K8 Stable selectors: no unstable key in the selector of a workload or a Service.
selector_keys contains [path, obj, key] if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	obj.kind in workload_kinds
	some key, _ in as_object(object.get(obj, ["spec", "selector", "matchLabels"], {}))
}

selector_keys contains [path, obj, expression.key] if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	obj.kind in workload_kinds
	some expression in as_array(object.get(obj, ["spec", "selector", "matchExpressions"], []))
}

selector_keys contains [path, obj, key] if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	obj.kind == "Service"
	some key, _ in as_object(object.get(obj, ["spec", "selector"], {}))
}

deny contains msg if {
	some [path, obj, key] in selector_keys
	key in data.labels.unstable_keys
	msg := sprintf("%s: K8: %s %q: the selector has the key %q, which changes at an upgrade. A selector is immutable.", [path, obj.kind, object_name(obj), key])
}

# K9 Argo CD tracking: the rendered argocd-cm ConfigMap.
# TODO(follow-up PR): change to deny after a later PR sets
# application.resourceTrackingMethod in the values of the argocd component.
warn contains msg if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	obj.kind == "ConfigMap"
	object_name(obj) == "argocd-cm"
	method := object.get(obj, ["data", "application.resourceTrackingMethod"], "")
	method != "annotation"
	msg := sprintf("%s: K9: ConfigMap \"argocd-cm\": application.resourceTrackingMethod is %q. Set it to \"annotation\".", [path, method])
}

# K10 Sync options: all objects in gitops/, with an allowlist for upstream exceptions.
sync_options contains [path, obj, trim_space(option)] if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	value := object.get(as_object(obj.metadata), ["annotations", "argocd.argoproj.io/sync-options"], "")
	is_string(value)
	some option in split(value, ",")
}

sync_options contains [path, obj, option] if {
	some [path, obj] in k8s_objects
	is_gitops(path)
	obj.kind == "Application"
	some option in as_array(object.get(obj, ["spec", "syncPolicy", "syncOptions"], []))
}

k10_allowlisted(path, obj, option) if {
	is_upstream(path)
	[_, component, _] := rendered_parts(path)
	some entry in data.labels.allowlists.sync_options_upstream
	entry == {"component": component, "kind": obj.kind, "name": object_name(obj), "option": option}
}

deny contains msg if {
	some [path, obj, option] in sync_options
	option in data.labels.forbidden_sync_options
	not k10_allowlisted(path, obj, option)
	msg := sprintf("%s: K10: %s %q: the sync option %s can delete objects and their data", [path, obj.kind, object_name(obj), option])
}

# K14 Pod Security of applications: the Namespace objects of the apps components.
deny contains msg if {
	some [path, obj] in gitops_namespaces
	in_group(path, "apps")
	not object_name(obj) in data.labels.allowlists.pod_security_apps
	level := object.get(as_object(obj.metadata), ["labels", "pod-security.kubernetes.io/enforce"], "")
	not level in data.labels.apps_pod_security_levels
	msg := sprintf("%s: K14: Namespace %q of an apps component: pod-security.kubernetes.io/enforce is %q. Use %s.", [path, object_name(obj), level, concat(" or ", data.labels.apps_pod_security_levels)])
}

# K15 Namespace of a component: each Namespace in rendered/<component>/ has the
# namespace of the component in cluster.yaml. The check needs the cluster.yaml
# of the cluster in the input: schemas:check makes sure that the file exists.
k15_allowlisted(path, obj) if {
	is_upstream(path)
	[_, component, _] := rendered_parts(path)
	some entry in data.labels.allowlists.upstream_namespaces
	entry == {"component": component, "namespace": object_name(obj)}
}

deny contains msg if {
	some [path, obj] in gitops_namespaces
	[cluster, component, _] := rendered_parts(path)
	cluster_files[cluster]
	expected := {entry[3] | some entry in cluster_components; entry[0] == cluster; entry[2] == component}
	not object_name(obj) in expected
	not k15_allowlisted(path, obj)
	msg := sprintf("%s: K15: Namespace %q: the namespace of the component %q in gitops/clusters/%s/cluster.yaml is %v", [path, object_name(obj), component, cluster, expected])
}

deny contains msg if {
	some cluster, _ in cluster_files
	namespaces := [entry[3] | some entry in cluster_components; entry[0] == cluster]
	some namespace in {n | some n in namespaces}
	count([n | some n in namespaces; n == namespace]) > 1
	msg := sprintf("gitops/clusters/%s/cluster.yaml: K15: more than one component has the namespace %q", [cluster, namespace])
}

deny contains msg if {
	some [cluster, "apps", component, namespace] in cluster_components
	some pattern in data.labels.allowlists.reserved_namespaces
	glob.match(pattern, [], namespace)
	msg := sprintf("gitops/clusters/%s/cluster.yaml: K15: the apps component %q uses the reserved namespace %q", [cluster, component, namespace])
}

# K16 Privileged containers: a pod or a pod template with a container that sets
# securityContext.privileged: true is permitted only in the namespaces of
# data.labels.allowlists.pod_security_privileged. The object has up to two
# namespaces: metadata.namespace, and the namespace of its component in
# cluster.yaml. Each one that is known must be in the allowlist, so a component
# cannot pass by setting an allowlisted metadata.namespace. An object with
# neither is refused.
container_fields := ["initContainers", "containers", "ephemeralContainers"]

privileged_containers(spec) := [c |
	some field in container_fields
	some c in as_array(object.get(spec, field, []))
	is_object(c)
	object.get(c, ["securityContext", "privileged"], false) == true
]

# The namespace of the component of a rendered object: empty if unknown.
component_namespaces(path) := {entry[3] |
	[cluster, component, _] := rendered_parts(path)
	some entry in cluster_components
	entry[0] == cluster
	entry[2] == component
	entry[3] != ""
}

component_namespaces(path) := set() if not rendered_parts(path)

candidate_namespaces(path, obj) := ({object.get(obj, ["metadata", "namespace"], "")} | component_namespaces(path)) - {""}

privileged_objects contains [path, obj, names] if {
	some [path, obj] in k8s_objects
	spec := pod_spec(obj)
	is_object(spec)
	privileged := privileged_containers(spec)
	count(privileged) > 0
	names := [object.get(c, "name", "") | some c in privileged]
}

deny contains msg if {
	some [path, obj, names] in privileged_objects
	count(candidate_namespaces(path, obj)) == 0
	msg := sprintf("%s: K16: %s %q: the container %v sets privileged: true, and the namespace is unknown. Set metadata.namespace, in one of the namespaces %v.", [path, obj.kind, object_name(obj), names, data.labels.allowlists.pod_security_privileged])
}

deny contains msg if {
	some [path, obj, names] in privileged_objects
	some namespace in candidate_namespaces(path, obj)
	not namespace in data.labels.allowlists.pod_security_privileged
	msg := sprintf("%s: K16: %s %q in namespace %q: the container %v sets privileged: true. Only the namespaces %v permit it.", [path, obj.kind, object_name(obj), namespace, names, data.labels.allowlists.pod_security_privileged])
}

# K17 Enforcement scope: a cluster-scoped Tetragon TracingPolicy acts on every
# process of the node, so it has no enforcement action. Enforcement belongs in a
# TracingPolicyNamespaced. The check walks the whole spec for matchActions and
# matchReturnActions, so it covers kprobes, fentries, tracepoints, uprobes,
# lsmhooks, usdts and selectorsMacros. It also refuses spec.enforcers, which
# carries out NotifyEnforcer.
# Action names: https://tetragon.io/docs/concepts/tracing-policy/selectors/
enforcement_actions := {"Sigkill", "Override", "Signal", "NotifyEnforcer", "Set"}

action_fields := {"matchActions", "matchReturnActions"}

enforcement_actions_of(obj) := {action |
	walk(object.get(obj, "spec", {}), [path, value])
	count(path) > 0
	path[count(path) - 1] in action_fields
	some match in as_array(value)
	action := object.get(match, "action", "")
	action in enforcement_actions
}

tracing_policies contains [path, obj] if {
	some [path, obj] in k8s_objects
	obj.kind == "TracingPolicy"
	startswith(obj.apiVersion, "cilium.io/")
}

deny contains msg if {
	some [path, obj] in tracing_policies
	actions := enforcement_actions_of(obj)
	count(actions) > 0
	msg := sprintf("%s: K17: TracingPolicy %q is cluster-scoped and has the enforcement actions %v. Use a TracingPolicyNamespaced.", [path, object_name(obj), sort(actions)])
}

deny contains msg if {
	some [path, obj] in tracing_policies
	count(as_array(object.get(obj, ["spec", "enforcers"], []))) > 0
	msg := sprintf("%s: K17: TracingPolicy %q is cluster-scoped and has spec.enforcers. Use a TracingPolicyNamespaced.", [path, object_name(obj)])
}

# K18 hostPath volumes: a pod or a pod template with a hostPath volume on
# /procHost, or on a parent path (such as /), is permitted only in the namespaces
# of data.labels.allowlists.host_path_procfs. The procfs magic links
# (/procHost/<pid>/root, cwd, fd, ns) give access to the whole Docker host, even
# with a read-only mount. The namespaces are read as in K16. A hostPath on a
# container runtime Docker socket is refused everywhere (Decision 29 of the
# runtime security plan): it controls the Docker host. Allowlists per tool for
# other host paths (KubeArmor, Tracee) come with those components.
# Operator-created pods are not visible here: the Falco and KubeArmorConfig CRs
# need a live check.
procfs_host_path := "/procHost"

docker_socket_paths := {"/var/run/docker.sock", "/run/docker.sock"}

# Normalizes a path: drops empty and "." segments, so //procHost/ and /./procHost
# give /procHost. A path with a ".." segment is refused (see below), so it is not
# resolved here.
normalize_path(p) := path if {
	segments := [s | some s in split(p, "/"); s != ""; s != "."]
	path := sprintf("/%s", [concat("/", segments)])
}

host_paths(spec) := [path |
	some volume in as_array(object.get(spec, "volumes", []))
	is_object(volume)
	p := object.get(volume, ["hostPath", "path"], "")
	is_string(p)
	p != ""
	path := normalize_path(p)
]

# True if the hostPath is /procHost, a path under it, or a parent of it.
reaches_procfs(path) if path == "/"

reaches_procfs(path) if path == procfs_host_path

reaches_procfs(path) if startswith(path, concat("", [procfs_host_path, "/"]))

procfs_host_path_objects contains [path, obj, hp] if {
	some [path, obj] in k8s_objects
	spec := pod_spec(obj)
	is_object(spec)
	some hp in host_paths(spec)
	reaches_procfs(hp)
}

deny contains msg if {
	some [path, obj, hp] in procfs_host_path_objects
	count(candidate_namespaces(path, obj)) == 0
	msg := sprintf("%s: K18: %s %q has a hostPath volume on %q, and the namespace is unknown. Set metadata.namespace, in one of the namespaces %v.", [path, obj.kind, object_name(obj), hp, data.labels.allowlists.host_path_procfs])
}

deny contains msg if {
	some [path, obj, hp] in procfs_host_path_objects
	some namespace in candidate_namespaces(path, obj)
	not namespace in data.labels.allowlists.host_path_procfs
	msg := sprintf("%s: K18: %s %q in namespace %q has a hostPath volume on %q. Only the namespaces %v permit a hostPath on %s or a parent path.", [path, obj.kind, object_name(obj), namespace, hp, data.labels.allowlists.host_path_procfs, procfs_host_path])
}

deny contains msg if {
	some [path, obj] in k8s_objects
	spec := pod_spec(obj)
	is_object(spec)
	some hp in host_paths(spec)
	hp in docker_socket_paths
	msg := sprintf("%s: K18: %s %q has a hostPath volume on the Docker socket %q. No namespace permits it: the socket controls the Docker host.", [path, obj.kind, object_name(obj), hp])
}

# A ".." segment hides the real path from the checks above.
deny contains msg if {
	some [path, obj] in k8s_objects
	spec := pod_spec(obj)
	is_object(spec)
	some hp in host_paths(spec)
	".." in split(hp, "/")
	msg := sprintf("%s: K18: %s %q has a hostPath volume on %q with a \"..\" segment. Write the resolved path.", [path, obj.kind, object_name(obj), hp])
}
