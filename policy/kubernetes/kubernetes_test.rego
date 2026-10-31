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
