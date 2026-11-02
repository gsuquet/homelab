package kubernetes_test

import data.kubernetes

digest := "sha256:d219d3a72847f3aed6a1d66975972d3b17f86e39e8f6f6b86b4088b879c1a2d6"

deployment(image) := {
	"kind": "Deployment",
	"spec": {"template": {"spec": {"containers": [{"name": "app", "image": image}]}}},
}

test_tag_and_digest_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "kubernetes/applications/mosquitto/deployment.yaml",
		"contents": deployment(sprintf("eclipse-mosquitto:2.0.22@%s", [digest])),
	}]
}

test_missing_digest_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "kubernetes/applications/mosquitto/deployment.yaml",
		"contents": deployment("eclipse-mosquitto:2.0.22"),
	}]
}

test_rendered_manifest_without_digest_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "kubernetes/bootstrap/argo-cd/manifests/server.yaml",
		"contents": deployment("quay.io/argoproj/argocd:v3.3.7"),
	}]
}

test_gitops_rendered_manifest_without_digest_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "gitops/clusters/kind-local/rendered/argocd/deployment-argocd-server.yaml",
		"contents": deployment("quay.io/argoproj/argocd:v3.5.6"),
	}]
}

test_gitops_hand_written_manifest_without_digest_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/infrastructure/example/extra/deployment.yaml",
		"contents": deployment("quay.io/argoproj/argocd:v3.5.6"),
	}]
}

test_latest_tag_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "kubernetes/bootstrap/argo-cd/manifests/server.yaml",
		"contents": deployment("quay.io/argoproj/argocd:latest"),
	}]
}

test_missing_tag_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "kubernetes/bootstrap/argo-cd/manifests/server.yaml",
		"contents": deployment("registry.local:5000/argocd"),
	}]
}

test_init_containers_are_checked if {
	obj := {
		"kind": "StatefulSet",
		"spec": {"template": {"spec": {
			"initContainers": [{"name": "init", "image": "busybox:1.37"}],
			"containers": [{"name": "app", "image": sprintf("eclipse-mosquitto:2.0.22@%s", [digest])}],
		}}},
	}
	count(kubernetes.deny) == 1 with input as [{"path": "kubernetes/applications/x/sts.yaml", "contents": obj}]
}

test_non_workload_is_ignored if {
	count(kubernetes.deny) == 0 with input as [{"path": "kubernetes/applications/x/svc.yaml", "contents": {"kind": "Service"}}]
}

application(revision) := {
	"kind": "Application",
	"metadata": {"name": "demo"},
	"spec": {"source": {"targetRevision": revision}},
}

application_path := "gitops/clusters/kind-local/rendered/argocd/application-demo.yaml"

test_application_on_main_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{"path": application_path, "contents": application("main")}]
}

test_application_on_a_branch_is_denied if {
	count(kubernetes.deny) == 1 with input as [{"path": application_path, "contents": application("feat/test")}]
}

namespace(labels, annotations) := {
	"kind": "Namespace",
	"metadata": {"name": "demo", "labels": labels, "annotations": annotations},
}

pss_labels := {
	"pod-security.kubernetes.io/enforce": "restricted",
	"pod-security.kubernetes.io/audit": "restricted",
	"pod-security.kubernetes.io/warn": "restricted",
}

test_namespace_with_pss_and_wave_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "gitops/clusters/kind-local/rendered/demo/namespace-demo.yaml",
		"contents": namespace(pss_labels, {"argocd.argoproj.io/sync-wave": "-2"}),
	}]
}

test_namespace_without_pss_is_denied if {
	count(kubernetes.deny) == 3 with input as [{
		"path": "gitops/clusters/kind-local/rendered/demo/namespace-demo.yaml",
		"contents": namespace({}, {"argocd.argoproj.io/sync-wave": "-2"}),
	}]
}

test_namespace_with_unknown_pss_level_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/clusters/kind-local/rendered/demo/namespace-demo.yaml",
		"contents": namespace(object.union(pss_labels, {"pod-security.kubernetes.io/warn": "strict"}), {"argocd.argoproj.io/sync-wave": "-2"}),
	}]
}

test_namespace_without_wave_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/clusters/kind-local/rendered/demo/namespace-demo.yaml",
		"contents": namespace(pss_labels, {}),
	}]
}

test_crd_without_wave_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/clusters/kind-local/rendered/demo/customresourcedefinition-demos.example.com.yaml",
		"contents": {"kind": "CustomResourceDefinition", "metadata": {"name": "demos.example.com"}},
	}]
}

test_crd_with_wave_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "gitops/clusters/kind-local/rendered/demo/customresourcedefinition-demos.example.com.yaml",
		"contents": {"kind": "CustomResourceDefinition", "metadata": {"name": "demos.example.com", "annotations": {"argocd.argoproj.io/sync-wave": "-1"}}},
	}]
}

test_namespace_outside_gitops_is_not_checked if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "kubernetes/system/demo/namespace.yaml",
		"contents": namespace({}, {}),
	}]
}

test_application_with_create_namespace_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": application_path,
		"contents": object.union(application("main"), {"spec": {"syncPolicy": {"syncOptions": ["CreateNamespace=true"]}}}),
	}]
}

test_application_with_resources_finalizer_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": application_path,
		"contents": object.union(application("main"), {"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io/background"]}}),
	}]
}

secret_path := "gitops/clusters/kind-local/rendered/demo/secret-demo.yaml"

secret(fields) := object.union({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "demo"}, "type": "Opaque"}, fields)

sops_metadata := {"age": [{"recipient": "age1example", "enc": "-----BEGIN AGE ENCRYPTED FILE-----"}], "version": "3.9.0"}

secret_denial(field) := named_secret_denial("demo", field)

named_secret_denial(name, field) := sprintf("%s: the Secret %q has values in %s that are not SOPS-encrypted. Remove %s, or encrypt it with SOPS.", [secret_path, name, field, field])

encrypted_value := "ENC[AES256_GCM,data:abc=,iv:def=,tag:ghi=,type:str]"

test_secret_without_data_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{"path": secret_path, "contents": secret({})}]
}

test_secret_with_empty_data_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{"path": secret_path, "contents": secret({"data": {}})}]
}

test_secret_with_data_is_denied if {
	kubernetes.deny == {secret_denial("data")} with input as [{
		"path": secret_path,
		"contents": secret({"data": {"key": "dmFsdWU="}}),
	}]
}

test_secret_with_string_data_is_denied if {
	kubernetes.deny == {secret_denial("stringData")} with input as [{
		"path": secret_path,
		"contents": secret({"stringData": {"key": "value"}}),
	}]
}

test_sops_encrypted_secret_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": secret_path,
		"contents": secret({
			"data": {"key": encrypted_value},
			"stringData": {"other": encrypted_value},
			"sops": sops_metadata,
		}),
	}]
}

test_sops_secret_with_plain_value_is_denied if {
	kubernetes.deny == {secret_denial("data")} with input as [{
		"path": secret_path,
		"contents": secret({
			"data": {
				"key": encrypted_value,
				"plain": "dmFsdWU=",
			},
			"sops": sops_metadata,
		}),
	}]
}

test_encrypted_values_without_sops_metadata_are_denied if {
	kubernetes.deny == {secret_denial("data")} with input as [{
		"path": secret_path,
		"contents": secret({"data": {"key": encrypted_value}}),
	}]
}

test_sops_metadata_not_an_object_is_denied if {
	kubernetes.deny == {secret_denial("data")} with input as [{
		"path": secret_path,
		"contents": secret({"data": {"key": encrypted_value}, "sops": "x"}),
	}]
}

test_empty_sops_metadata_is_denied if {
	kubernetes.deny == {secret_denial("stringData")} with input as [{
		"path": secret_path,
		"contents": secret({"stringData": {"key": "ENC[ plaintext"}, "sops": {}}),
	}]
}

test_sops_metadata_without_version_is_denied if {
	kubernetes.deny == {secret_denial("data")} with input as [{
		"path": secret_path,
		"contents": secret({"data": {"key": encrypted_value}, "sops": {"age": []}}),
	}]
}

test_enc_value_without_aes256_gcm_prefix_is_denied if {
	kubernetes.deny == {secret_denial("stringData")} with input as [{
		"path": secret_path,
		"contents": secret({"stringData": {"key": "ENC[ plaintext"}, "sops": sops_metadata}),
	}]
}

test_non_string_data_value_is_denied if {
	kubernetes.deny == {secret_denial("data")} with input as [{
		"path": secret_path,
		"contents": secret({"data": {"key": 42}, "sops": sops_metadata}),
	}]
}

test_multi_document_file_with_plain_secret_is_denied if {
	kubernetes.deny == {named_secret_denial("plain", "data")} with input as [{
		"path": secret_path,
		"contents": [
			{"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "demo"}, "data": {"key": "value"}},
			secret({"metadata": {"name": "empty"}}),
			secret({"metadata": {"name": "plain"}, "data": {"key": "dmFsdWU="}}),
		],
	}]
}

test_list_with_plain_secret_is_denied if {
	kubernetes.deny == {named_secret_denial("plain", "stringData")} with input as [{
		"path": secret_path,
		"contents": {"apiVersion": "v1", "kind": "List", "items": [
			secret({"metadata": {"name": "empty"}}),
			secret({"metadata": {"name": "plain"}, "stringData": {"key": "value"}}),
		]},
	}]
}

test_list_with_sops_secret_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": secret_path,
		"contents": {"apiVersion": "v1", "kind": "List", "items": [secret({"data": {"key": encrypted_value}, "sops": sops_metadata})]},
	}]
}

test_secret_with_plain_data_and_string_data_is_denied_twice if {
	kubernetes.deny == {secret_denial("data"), secret_denial("stringData")} with input as [{
		"path": secret_path,
		"contents": secret({"data": {"key": "dmFsdWU="}, "stringData": {"other": "value"}}),
	}]
}

test_secret_with_string_as_data_is_denied if {
	kubernetes.deny == {secret_denial("data")} with input as [{
		"path": secret_path,
		"contents": secret({"data": "cGxhaW4="}),
	}]
}

test_secret_with_null_data_and_plain_string_data_is_denied_once if {
	kubernetes.deny == {secret_denial("stringData")} with input as [{
		"path": secret_path,
		"contents": secret({"data": null, "stringData": {"key": "value"}}),
	}]
}

test_list_with_null_items_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": secret_path,
		"contents": {"apiVersion": "v1", "kind": "List", "items": null},
	}]
}

test_multi_document_file_with_null_document_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": secret_path,
		"contents": [null, secret({})],
	}]
}

test_configmap_with_data_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "gitops/clusters/kind-local/rendered/demo/configmap-demo.yaml",
		"contents": {"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "demo"}, "data": {"key": "value"}},
	}]
}

# ---------------------------------------------------------------------------
# Label and annotation keys: K1 to K10, K14 and K15.

# The messages of one check.
check(messages, id) := {m | some m in messages; contains(m, sprintf(": %s: ", [id]))}

cluster_file(infrastructure, apps) := {
	"path": "gitops/clusters/kind/cluster.yaml",
	"contents": {
		"apiVersion": "infra.gsuquet.com/v1alpha1",
		"kind": "GitOpsCluster",
		"name": "kind",
		"infrastructure": infrastructure,
		"apps": apps,
	},
}

kind_cluster := cluster_file([{"name": "argocd", "namespace": "argocd"}], [{"name": "web", "namespace": "web"}])

# data.labels with an apps component web, of the tenant home.
web_data := object.union(data.labels, {"components": {"web": {"tenant": "home", "network": {"zone": ["internal"], "exposure": []}}}})

rendered(component, file) := sprintf("gitops/clusters/kind/rendered/%s/%s", [component, file])

app_labels := {
	"app.kubernetes.io/name": "demo",
	"app.kubernetes.io/instance": "demo",
	"app.kubernetes.io/managed-by": "Helm",
}

pod_labels := {
	"app.kubernetes.io/name": "demo",
	"app.kubernetes.io/instance": "demo",
	"app.kubernetes.io/part-of": "demo",
}

namespace_labels(tenant) := object.union(object.union(pss_labels, app_labels), {
	"tenant.infra.gsuquet.com/name": tenant,
	"ownership.infra.gsuquet.com/owner": "gsuquet",
})

labelled_namespace(name, labels) := {
	"apiVersion": "v1",
	"kind": "Namespace",
	"metadata": {"name": name, "labels": labels, "annotations": {"argocd.argoproj.io/sync-wave": "-2"}},
}

argocd_namespace := labelled_namespace("argocd", namespace_labels("platform"))

web_namespace(labels) := {"path": rendered("web", "namespace-web.yaml"), "contents": labelled_namespace("web", labels)}

# A Deployment with the labels and annotations of its metadata and of its pod template.
workload(labels, annotations, template_labels) := {
	"apiVersion": "apps/v1",
	"kind": "Deployment",
	"metadata": {"name": "demo", "labels": labels, "annotations": annotations},
	"spec": {
		"selector": {"matchLabels": {"app.kubernetes.io/name": "demo"}},
		"template": {
			"metadata": {"labels": template_labels},
			"spec": {"containers": [{"name": "app", "image": sprintf("busybox:1.37@%s", [digest])}]},
		},
	},
}

good_workload := workload(app_labels, {}, pod_labels)

config_map(labels, annotations) := {
	"apiVersion": "v1",
	"kind": "ConfigMap",
	"metadata": {"name": "demo", "labels": object.union(app_labels, labels), "annotations": annotations},
}

hand_written(contents) := {"path": rendered("argocd", "configmap-demo.yaml"), "contents": contents}

upstream(contents) := {"path": rendered("argocd", "upstream--configmap-demo.yaml"), "contents": contents}

with_config_map(labels, annotations) := [kind_cluster, hand_written(config_map(labels, annotations))]

# The data file.

test_data_defines_the_six_subgroups if {
	object.keys(data.labels.subgroups) == {"tenant", "instance", "ownership", "network", "backup", "cost"}
}

test_data_required_keys_are_keys_of_the_subgroups if {
	required := array.concat(
		array.concat(data.labels.required.namespace.labels, data.labels.required.cloud.labels),
		data.labels.required.cloud.ephemeral_labels,
	)
	every key in required {
		kubernetes.key_spec(key).type == "label"
	}
}

test_data_required_namespace_keys_are_permitted_on_a_namespace if {
	every key in data.labels.required.namespace.labels {
		"Namespace" in kubernetes.key_spec(key).kinds
	}
}

test_data_required_cloud_keys_are_cloud_keys if {
	every key in array.concat(data.labels.required.cloud.labels, data.labels.required.cloud.ephemeral_labels) {
		kubernetes.key_spec(key).cloud == true
	}
}

test_missing_data_is_denied if {
	"policy/data/labels.yaml is not loaded: run conftest with --data policy/data" in kubernetes.deny with input as [] with data.labels as null
}

test_data_without_forbidden_sync_options_is_denied if {
	labels := object.remove(data.labels, ["forbidden_sync_options"])
	"policy/data/labels.yaml: labels.forbidden_sync_options must have the type array, not null" in kubernetes.deny with input as [] with data.labels as labels
}

test_data_without_required_object_labels_is_denied if {
	labels := json.remove(data.labels, ["required/object"])
	"policy/data/labels.yaml: labels.required.object.labels must have the type array, not null" in kubernetes.deny with input as [] with data.labels as labels
}

test_data_with_empty_unstable_keys_is_denied if {
	labels := object.union(data.labels, {"unstable_keys": []})
	kubernetes.deny == {"policy/data/labels.yaml: labels.unstable_keys must not be empty"} with input as [] with data.labels as labels
}

test_data_with_wrong_type_is_denied if {
	labels := object.union(data.labels, {"prefix": ["infra.gsuquet.com"]})
	"policy/data/labels.yaml: labels.prefix must have the type string, not array" in kubernetes.deny with input as [] with data.labels as labels
}

test_data_with_empty_allowlist_is_allowed if {
	labels := object.union(data.labels, {"components": {}, "allowlists": {"no_prefix": []}})
	count(kubernetes.deny) == 0 with input as [] with data.labels as labels
}

test_loaded_data_is_allowed if {
	count(kubernetes.deny) == 0 with input as []
}

test_complete_objects_are_allowed if {
	inputs := [
		kind_cluster,
		{"path": rendered("argocd", "namespace-argocd.yaml"), "contents": argocd_namespace},
		{"path": rendered("argocd", "deployment-demo.yaml"), "contents": good_workload},
		web_namespace(namespace_labels("home")),
	]
	count(kubernetes.deny) == 0 with input as inputs with data.labels as web_data
	count(kubernetes.warn) == 0 with input as inputs with data.labels as web_data
}

# K1 Syntax

test_k1_valid_keys_and_values_are_allowed if {
	count(check(kubernetes.deny, "K1")) == 0 with input as with_config_map(
		{"example.com/a_b.c": "Value_1.x", "example.com/empty": ""},
		{"example.com/note": "Any text, with spaces: yes."},
	)
}

test_k1_key_with_two_slashes_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({"example.com/a/b": "x"}, {})
}

test_k1_key_with_a_bad_prefix_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({}, {"Example.com/a": "x"})
}

test_k1_key_name_of_64_characters_is_denied if {
	name := concat("", [c | some _ in numbers.range(1, 64); c := "a"])
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({sprintf("example.com/%s", [name]): "x"}, {})
}

test_k1_key_name_that_ends_with_a_dash_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({"example.com/a-": "x"}, {})
}

test_k1_label_value_with_a_space_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({"example.com/a": "two words"}, {})
}

test_k1_label_value_of_64_characters_is_denied if {
	value := concat("", [c | some _ in numbers.range(1, 64); c := "a"])
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({"example.com/a": value}, {})
}

test_k1_label_value_that_is_a_number_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({"example.com/a": 42}, {})
}

test_k1_annotation_value_that_is_a_number_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({}, {"argocd.argoproj.io/sync-wave": -2})
}

test_k1_custom_key_name_with_an_underscore_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({}, {"ownership.infra.gsuquet.com/con_tact": "https://example.com"})
}

test_k1_custom_label_value_with_an_uppercase_letter_is_denied if {
	count(check(kubernetes.deny, "K1")) == 1 with input as [
		kind_cluster,
		{"path": rendered("argocd", "namespace-argocd.yaml"), "contents": labelled_namespace("argocd", object.union(namespace_labels("platform"), {"ownership.infra.gsuquet.com/owner": "GSuquet"}))},
	]
}

test_k1_annotations_over_256_kib_are_denied if {
	block := concat("", [c | some _ in numbers.range(1, 1024); c := "a"])
	value := concat("", [block | some _ in numbers.range(1, 257)])
	count(check(kubernetes.deny, "K1")) == 1 with input as with_config_map({}, {"example.com/a": value})
}

test_k1_checks_the_pod_template if {
	count(check(kubernetes.deny, "K1")) == 1 with input as [kind_cluster, {
		"path": rendered("argocd", "deployment-demo.yaml"),
		"contents": workload(app_labels, {}, object.union(pod_labels, {"example.com/a": "bad value"})),
	}]
}

test_k1_checks_the_legacy_files if {
	count(check(kubernetes.deny, "K1")) == 1 with input as [{
		"path": "kubernetes/applications/demo/configmap.yaml",
		"contents": config_map({"bad key": "x"}, {}),
	}]
}

test_legacy_files_get_only_k1 if {
	inputs := [{"path": "kubernetes/applications/demo/configmap.yaml", "contents": config_map({"app": "demo", "node.kubernetes.io/x": "y", "foo.infra.gsuquet.com/x": "y"}, {})}]
	count(kubernetes.deny) == 0 with input as inputs
	count(kubernetes.warn) == 0 with input as inputs
}

# K2 Reserved prefixes

test_k2_allowlisted_reserved_keys_are_allowed if {
	count(check(kubernetes.deny, "K2")) == 0 with input as with_config_map(
		{"kubernetes.io/os": "linux", "node-restriction.kubernetes.io/zone": "dmz"},
		{"kubectl.kubernetes.io/default-container": "app", "gateway.networking.k8s.io/channel": "standard"},
	)
}

test_k2_reserved_key_is_denied if {
	count(check(kubernetes.deny, "K2")) == 1 with input as with_config_map({"node.kubernetes.io/instance-type": "small"}, {})
}

test_k2_key_of_k8s_io_is_denied if {
	count(check(kubernetes.deny, "K2")) == 1 with input as with_config_map({}, {"k8s.io/x": "y"})
}

test_k2_pod_security_version_label_is_denied if {
	count(check(kubernetes.deny, "K2")) == 1 with input as with_config_map({"pod-security.kubernetes.io/enforce-version": "latest"}, {})
}

test_k2_does_not_check_upstream_objects if {
	count(check(kubernetes.deny, "K2")) == 0 with input as [kind_cluster, upstream(config_map({"node.kubernetes.io/instance-type": "small"}, {}))]
}

test_k2_does_not_read_selectors if {
	obj := object.union(good_workload, {"spec": {"template": {"spec": {"nodeSelector": {"node.kubernetes.io/instance-type": "small"}}}}})
	count(check(kubernetes.deny, "K2")) == 0 with input as [kind_cluster, {"path": rendered("argocd", "deployment-demo.yaml"), "contents": obj}]
}

# K3 and K3w No prefix

test_k3_key_without_prefix_is_denied if {
	count(check(kubernetes.deny, "K3")) == 1 with input as with_config_map({"app": "demo"}, {})
}

test_k3_allowlisted_key_without_prefix_is_allowed if {
	labels := object.union(data.labels, {"allowlists": {"no_prefix": ["app"]}})
	count(check(kubernetes.deny, "K3")) == 0 with input as with_config_map({"app": "demo"}, {}) with data.labels as labels
}

test_k3w_upstream_key_without_prefix_is_a_warning if {
	inputs := [kind_cluster, upstream(config_map({}, {"checksum": "abc"}))]
	count(check(kubernetes.deny, "K3")) == 0 with input as inputs
	count(check(kubernetes.warn, "K3w")) == 1 with input as inputs
}

# K4 Custom keys

argocd_namespace_with(labels, annotations) := [kind_cluster, {
	"path": rendered("argocd", "namespace-argocd.yaml"),
	"contents": {
		"apiVersion": "v1",
		"kind": "Namespace",
		"metadata": {
			"name": "argocd",
			"labels": object.union(namespace_labels("platform"), labels),
			"annotations": object.union({"argocd.argoproj.io/sync-wave": "-2"}, annotations),
		},
	},
}]

test_k4_permitted_keys_are_allowed if {
	count(check(kubernetes.deny, "K4")) == 0 with input as argocd_namespace_with({}, {"ownership.infra.gsuquet.com/contact": "https://github.com/gsuquet"})
}

test_k4_contact_address_is_allowed if {
	count(check(kubernetes.deny, "K4")) == 0 with input as argocd_namespace_with({}, {"ownership.infra.gsuquet.com/contact": "owner@example.com"})
}

test_k4_contact_with_a_space_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({}, {"ownership.infra.gsuquet.com/contact": "a person"})
}

test_k4_unknown_subgroup_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"team.infra.gsuquet.com/name": "x"}, {})
}

test_k4_key_without_subgroup_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"infra.gsuquet.com/tenant": "platform"}, {})
}

test_k4_unknown_key_name_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"tenant.infra.gsuquet.com/id": "platform"}, {})
}

test_k4_label_as_annotation_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({}, {"tenant.infra.gsuquet.com/name": "platform"})
}

test_k4_annotation_as_label_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"ownership.infra.gsuquet.com/contact": "gsuquet"}, {})
}

test_k4_tenant_on_a_config_map_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as with_config_map({"tenant.infra.gsuquet.com/name": "platform"}, {})
}

test_k4_tenant_on_a_pod_template_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as [kind_cluster, {
		"path": rendered("argocd", "deployment-demo.yaml"),
		"contents": workload(app_labels, {}, object.union(pod_labels, {"tenant.infra.gsuquet.com/name": "platform"})),
	}]
}

test_k4_instance_key_on_a_kubernetes_object_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"instance.infra.gsuquet.com/name": "kind"}, {})
}

test_k4_cost_key_on_a_kubernetes_object_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"cost.infra.gsuquet.com/center": "lab"}, {})
}

test_k4_wrong_tenant_of_an_infrastructure_component_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"tenant.infra.gsuquet.com/name": "home"}, {})
}

test_k4_tenant_of_an_apps_component_is_allowed if {
	count(check(kubernetes.deny, "K4")) == 0 with input as [kind_cluster, web_namespace(namespace_labels("home"))] with data.labels as web_data
}

test_k4_platform_tenant_of_an_apps_component_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as [kind_cluster, web_namespace(namespace_labels("platform"))] with data.labels as web_data
}

test_k4_apps_component_without_tenant_in_data_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as [kind_cluster, web_namespace(namespace_labels("home"))]
}

test_k4_tenant_without_cluster_file_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as [web_namespace(namespace_labels("home"))] with data.labels as web_data
}

test_k4_wrong_owner_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"ownership.infra.gsuquet.com/owner": "someone"}, {})
}

test_k4_permitted_network_value_is_allowed if {
	labels := object.union(namespace_labels("home"), {"network.infra.gsuquet.com/zone": "internal"})
	count(check(kubernetes.deny, "K4")) == 0 with input as [kind_cluster, web_namespace(labels)] with data.labels as web_data
}

test_k4_network_value_of_another_component_is_denied if {
	labels := object.union(namespace_labels("home"), {"network.infra.gsuquet.com/zone": "dmz"})
	count(check(kubernetes.deny, "K4")) == 1 with input as [kind_cluster, web_namespace(labels)] with data.labels as web_data
}

test_k4_network_key_before_it_is_required_is_checked if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"network.infra.gsuquet.com/exposure": "public"}, {})
}

test_k4_wrong_network_key_name_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as argocd_namespace_with({"network.infra.gsuquet.com/zones": "internal"}, {})
}

test_k4_network_key_on_a_config_map_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as with_config_map({"network.infra.gsuquet.com/zone": "internal"}, {})
}

test_k4_backup_key_before_it_is_required_is_checked if {
	pvc := {"apiVersion": "v1", "kind": "PersistentVolumeClaim", "metadata": {"name": "data", "labels": object.union(app_labels, {"backup.infra.gsuquet.com/policy": "daily"})}}
	count(check(kubernetes.deny, "K4")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "persistentvolumeclaim-data.yaml"), "contents": pvc}]
}

test_k4_backup_key_on_a_config_map_is_denied if {
	count(check(kubernetes.deny, "K4")) == 1 with input as with_config_map({}, {"backup.infra.gsuquet.com/retention": "7d"})
}

test_k4_backup_value_from_data_is_allowed if {
	labels := object.union(data.labels, {"subgroups": {"backup": {"keys": {"policy": {"values": ["daily"]}}}}})
	count(check(kubernetes.deny, "K4")) == 0 with input as argocd_namespace_with({"backup.infra.gsuquet.com/policy": "daily"}, {}) with data.labels as labels
}

test_k4_checks_upstream_objects if {
	count(check(kubernetes.deny, "K4")) == 1 with input as [kind_cluster, upstream(config_map({"tenant.infra.gsuquet.com/name": "platform"}, {}))]
}

test_k4_allowlisted_upstream_key_is_allowed if {
	entry := {"component": "argocd", "kind": "ConfigMap", "name": "demo", "key": "tenant.infra.gsuquet.com/name"}
	labels := object.union(data.labels, {"allowlists": {"custom_keys_upstream": [entry]}})
	count(check(kubernetes.deny, "K4")) == 0 with input as [kind_cluster, upstream(config_map({"tenant.infra.gsuquet.com/name": "platform"}, {}))] with data.labels as labels
}

test_k4_allowlist_does_not_apply_to_hand_written_objects if {
	entry := {"component": "argocd", "kind": "ConfigMap", "name": "demo", "key": "tenant.infra.gsuquet.com/name"}
	labels := object.union(data.labels, {"allowlists": {"custom_keys_upstream": [entry]}})
	count(check(kubernetes.deny, "K4")) == 1 with input as with_config_map({"tenant.infra.gsuquet.com/name": "platform"}, {}) with data.labels as labels
}

# K5 Required keys (warn until the follow-up PR)

test_k5_namespace_with_required_keys_has_no_warning if {
	count(check(kubernetes.warn, "K5")) == 0 with input as argocd_namespace_with({}, {})
}

test_k5_namespace_without_tenant_is_a_warning if {
	inputs := [kind_cluster, {"path": rendered("argocd", "namespace-argocd.yaml"), "contents": labelled_namespace("argocd", object.remove(namespace_labels("platform"), ["tenant.infra.gsuquet.com/name"]))}]
	check(kubernetes.warn, "K5") == {`gitops/clusters/kind/rendered/argocd/namespace-argocd.yaml: K5: Namespace "argocd": the label "tenant.infra.gsuquet.com/name" is missing`} with input as inputs
}

test_k5_namespace_without_owner_is_a_warning if {
	inputs := [kind_cluster, {"path": rendered("argocd", "namespace-argocd.yaml"), "contents": labelled_namespace("argocd", object.remove(namespace_labels("platform"), ["ownership.infra.gsuquet.com/owner"]))}]
	count(check(kubernetes.warn, "K5")) == 1 with input as inputs
}

test_k5_does_not_check_namespaces_outside_gitops if {
	count(check(kubernetes.warn, "K5")) == 0 with input as [{"path": "kubernetes/system/demo/namespace.yaml", "contents": labelled_namespace("demo", {})}]
}

test_k5_platform_tenant_in_components_is_denied if {
	labels := object.union(data.labels, {"components": {"web": {"tenant": "platform"}}})
	count(check(kubernetes.deny, "K5")) == 1 with input as [] with data.labels as labels
}

# K6 and K7 Required keys of workloads (K6 warns until the follow-up PR)

test_k6_workload_with_required_keys_has_no_warning if {
	count(check(kubernetes.warn, "K6")) == 0 with input as [kind_cluster, {"path": rendered("argocd", "deployment-demo.yaml"), "contents": good_workload}]
}

test_k6_pod_template_without_part_of_is_a_warning if {
	obj := workload(app_labels, {}, object.remove(pod_labels, ["app.kubernetes.io/part-of"]))
	check(kubernetes.warn, "K6") == {`gitops/clusters/kind/rendered/argocd/deployment-demo.yaml: K6: Deployment "demo", pod template: the label "app.kubernetes.io/part-of" is missing`} with input as [kind_cluster, {"path": rendered("argocd", "deployment-demo.yaml"), "contents": obj}]
}

test_k6_object_without_managed_by_is_a_warning if {
	obj := workload(object.remove(app_labels, ["app.kubernetes.io/managed-by"]), {}, pod_labels)
	count(check(kubernetes.warn, "K6")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "deployment-demo.yaml"), "contents": obj}]
}

test_k7_upstream_object_without_required_keys_is_a_warning if {
	inputs := [kind_cluster, upstream({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "demo"}})]
	count(check(kubernetes.warn, "K6")) == 0 with input as inputs
	count(check(kubernetes.warn, "K7")) == 3 with input as inputs
	count(kubernetes.deny) == 0 with input as inputs
}

# K8 Stable selectors

test_k8_stable_selectors_are_allowed if {
	service := {"apiVersion": "v1", "kind": "Service", "metadata": {"name": "demo", "labels": app_labels}, "spec": {"selector": {"app.kubernetes.io/name": "demo", "app.kubernetes.io/instance": "demo"}}}
	count(check(kubernetes.deny, "K8")) == 0 with input as [
		kind_cluster,
		{"path": rendered("argocd", "deployment-demo.yaml"), "contents": good_workload},
		{"path": rendered("argocd", "service-demo.yaml"), "contents": service},
	]
}

test_k8_version_in_a_workload_selector_is_denied if {
	obj := object.union(good_workload, {"spec": {"selector": {"matchLabels": {"app.kubernetes.io/version": "1.0.0"}}}})
	count(check(kubernetes.deny, "K8")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "upstream--deployment-demo.yaml"), "contents": obj}]
}

test_k8_chart_in_a_match_expression_is_denied if {
	obj := object.union(good_workload, {"spec": {"selector": {"matchExpressions": [{"key": "helm.sh/chart", "operator": "Exists"}]}}})
	count(check(kubernetes.deny, "K8")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "deployment-demo.yaml"), "contents": obj}]
}

test_k8_chart_in_a_service_selector_is_denied if {
	service := {"apiVersion": "v1", "kind": "Service", "metadata": {"name": "demo", "labels": app_labels}, "spec": {"selector": {"helm.sh/chart": "demo-1.0.0"}}}
	count(check(kubernetes.deny, "K8")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "service-demo.yaml"), "contents": service}]
}

# K9 Argo CD tracking (warn until the follow-up PR)

argocd_cm(cm_data) := [kind_cluster, {
	"path": rendered("argocd", "upstream--configmap-argocd-cm.yaml"),
	"contents": {"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "argocd-cm", "labels": app_labels}, "data": cm_data},
}]

test_k9_annotation_tracking_has_no_warning if {
	count(check(kubernetes.warn, "K9")) == 0 with input as argocd_cm({"application.resourceTrackingMethod": "annotation"})
}

test_k9_missing_tracking_method_is_a_warning if {
	count(check(kubernetes.warn, "K9")) == 1 with input as argocd_cm({"url": "https://argocd.example.com"})
}

test_k9_label_tracking_is_a_warning if {
	count(check(kubernetes.warn, "K9")) == 1 with input as argocd_cm({"application.resourceTrackingMethod": "label"})
}

# K10 Sync options

test_k10_safe_sync_options_are_allowed if {
	count(check(kubernetes.deny, "K10")) == 0 with input as with_config_map({}, {"argocd.argoproj.io/sync-options": "Prune=false,Delete=false,ServerSideApply=true"})
}

test_k10_replace_in_the_annotation_is_denied if {
	count(check(kubernetes.deny, "K10")) == 1 with input as with_config_map({}, {"argocd.argoproj.io/sync-options": "Prune=false, Replace=true"})
}

test_k10_force_in_an_application_is_denied if {
	count(check(kubernetes.deny, "K10")) == 1 with input as [{
		"path": application_path,
		"contents": object.union(application("main"), {"apiVersion": "argoproj.io/v1alpha1", "spec": {"syncPolicy": {"syncOptions": ["ServerSideApply=true", "Force=true"]}}}),
	}]
}

test_k10_checks_upstream_objects if {
	count(check(kubernetes.deny, "K10")) == 1 with input as [kind_cluster, upstream(config_map({}, {"argocd.argoproj.io/sync-options": "Force=true"}))]
}

test_k10_allowlisted_upstream_option_is_allowed if {
	entry := {"component": "argocd", "kind": "ConfigMap", "name": "demo", "option": "Force=true"}
	labels := object.union(data.labels, {"allowlists": {"sync_options_upstream": [entry]}})
	count(check(kubernetes.deny, "K10")) == 0 with input as [kind_cluster, upstream(config_map({}, {"argocd.argoproj.io/sync-options": "Force=true"}))] with data.labels as labels
}

test_k10_allowlist_does_not_apply_to_hand_written_objects if {
	entry := {"component": "argocd", "kind": "ConfigMap", "name": "demo", "option": "Force=true"}
	labels := object.union(data.labels, {"allowlists": {"sync_options_upstream": [entry]}})
	count(check(kubernetes.deny, "K10")) == 1 with input as with_config_map({}, {"argocd.argoproj.io/sync-options": "Force=true"}) with data.labels as labels
}

# K14 Pod Security of applications

web_pss(level) := object.union(namespace_labels("home"), {"pod-security.kubernetes.io/enforce": level})

test_k14_restricted_and_baseline_apps_namespaces_are_allowed if {
	count(check(kubernetes.deny, "K14")) == 0 with input as [kind_cluster, web_namespace(web_pss("restricted"))] with data.labels as web_data
	count(check(kubernetes.deny, "K14")) == 0 with input as [kind_cluster, web_namespace(web_pss("baseline"))] with data.labels as web_data
}

test_k14_privileged_apps_namespace_is_denied if {
	count(check(kubernetes.deny, "K14")) == 1 with input as [kind_cluster, web_namespace(web_pss("privileged"))] with data.labels as web_data
}

test_k14_allowlisted_privileged_apps_namespace_is_allowed if {
	labels := object.union(web_data, {"allowlists": {"pod_security_apps": ["web"]}})
	count(check(kubernetes.deny, "K14")) == 0 with input as [kind_cluster, web_namespace(web_pss("privileged"))] with data.labels as labels
}

test_k14_does_not_check_infrastructure_namespaces if {
	labels := object.union(namespace_labels("platform"), {"pod-security.kubernetes.io/enforce": "privileged"})
	count(check(kubernetes.deny, "K14")) == 0 with input as [kind_cluster, {"path": rendered("argocd", "namespace-argocd.yaml"), "contents": labelled_namespace("argocd", labels)}]
}

# K15 Namespace of a component

test_k15_namespace_of_the_component_is_allowed if {
	count(check(kubernetes.deny, "K15")) == 0 with input as argocd_namespace_with({}, {})
}

test_k15_namespace_with_another_name_is_denied if {
	count(check(kubernetes.deny, "K15")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "namespace-other.yaml"), "contents": labelled_namespace("other", namespace_labels("platform"))}]
}

test_k15_namespace_of_a_component_not_in_cluster_file_is_denied if {
	count(check(kubernetes.deny, "K15")) == 1 with input as [kind_cluster, {"path": rendered("ghost", "namespace-ghost.yaml"), "contents": labelled_namespace("ghost", namespace_labels("platform"))}]
}

test_k15_upstream_namespace_with_another_name_is_denied if {
	count(check(kubernetes.deny, "K15")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "upstream--namespace-other.yaml"), "contents": labelled_namespace("other", namespace_labels("platform"))}]
}

test_k15_allowlisted_upstream_namespace_is_allowed if {
	labels := object.union(data.labels, {"allowlists": {"upstream_namespaces": [{"component": "argocd", "namespace": "other"}]}})
	count(check(kubernetes.deny, "K15")) == 0 with input as [kind_cluster, {"path": rendered("argocd", "upstream--namespace-other.yaml"), "contents": labelled_namespace("other", namespace_labels("platform"))}] with data.labels as labels
}

test_k15_allowlist_does_not_apply_to_hand_written_namespaces if {
	labels := object.union(data.labels, {"allowlists": {"upstream_namespaces": [{"component": "argocd", "namespace": "other"}]}})
	count(check(kubernetes.deny, "K15")) == 1 with input as [kind_cluster, {"path": rendered("argocd", "namespace-other.yaml"), "contents": labelled_namespace("other", namespace_labels("platform"))}] with data.labels as labels
}

test_k15_needs_the_cluster_file if {
	count(check(kubernetes.deny, "K15")) == 0 with input as [{"path": rendered("argocd", "namespace-other.yaml"), "contents": labelled_namespace("other", namespace_labels("platform"))}]
}

test_k15_same_namespace_twice_in_cluster_file_is_denied if {
	cluster := cluster_file([{"name": "argocd", "namespace": "argocd"}], [{"name": "web", "namespace": "web"}, {"name": "blog", "namespace": "web"}])
	check(kubernetes.deny, "K15") == {`gitops/clusters/kind/cluster.yaml: K15: more than one component has the namespace "web"`} with input as [cluster]
}

test_k15_reserved_namespace_of_an_apps_component_is_denied if {
	cluster := cluster_file([{"name": "argocd", "namespace": "argocd"}], [{"name": "web", "namespace": "kube-public"}, {"name": "blog", "namespace": "default"}])
	count(check(kubernetes.deny, "K15")) == 2 with input as [cluster]
}

test_k15_terraform_namespace_of_an_apps_component_is_denied if {
	cluster := cluster_file([{"name": "argocd", "namespace": "argocd"}], [{"name": "web", "namespace": "cert-manager"}])
	count(check(kubernetes.deny, "K15")) == 1 with input as [cluster]
}

test_k15_reserved_namespace_of_an_infrastructure_component_is_allowed if {
	count(check(kubernetes.deny, "K15")) == 0 with input as [kind_cluster]
}
