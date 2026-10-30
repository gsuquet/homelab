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
		"path": "gitops/platform/argocd/rendered/kind-local/argocd-server-deployment.yaml",
		"contents": deployment("quay.io/argoproj/argocd:v3.5.6"),
	}]
}

test_gitops_hand_written_manifest_without_digest_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/platform/example/extra/deployment.yaml",
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

applicationset(revision) := {
	"kind": "ApplicationSet",
	"spec": {"template": {"spec": {"source": {"targetRevision": revision}}}},
}

test_applicationset_on_main_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "gitops/platform/argocd/rendered/kind-local/applicationsets.yaml",
		"contents": applicationset("main"),
	}]
}

test_applicationset_on_a_branch_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/platform/argocd/rendered/kind-local/applicationsets.yaml",
		"contents": applicationset("feat/test"),
	}]
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
		"path": "gitops/platform/demo/rendered/kind-local/namespace.yaml",
		"contents": namespace(pss_labels, {"argocd.argoproj.io/sync-wave": "-2"}),
	}]
}

test_namespace_without_pss_is_denied if {
	count(kubernetes.deny) == 3 with input as [{
		"path": "gitops/platform/demo/rendered/kind-local/namespace.yaml",
		"contents": namespace({}, {"argocd.argoproj.io/sync-wave": "-2"}),
	}]
}

test_namespace_with_unknown_pss_level_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/platform/demo/rendered/kind-local/namespace.yaml",
		"contents": namespace(object.union(pss_labels, {"pod-security.kubernetes.io/warn": "strict"}), {"argocd.argoproj.io/sync-wave": "-2"}),
	}]
}

test_namespace_without_wave_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/platform/demo/rendered/kind-local/namespace.yaml",
		"contents": namespace(pss_labels, {}),
	}]
}

test_crd_without_wave_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/platform/demo/rendered/kind-local/crd.yaml",
		"contents": {"kind": "CustomResourceDefinition", "metadata": {"name": "demos.example.com"}},
	}]
}

test_crd_with_wave_is_allowed if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "gitops/platform/demo/rendered/kind-local/crd.yaml",
		"contents": {"kind": "CustomResourceDefinition", "metadata": {"name": "demos.example.com", "annotations": {"argocd.argoproj.io/sync-wave": "-1"}}},
	}]
}

test_namespace_outside_gitops_is_not_checked if {
	count(kubernetes.deny) == 0 with input as [{
		"path": "kubernetes/system/demo/namespace.yaml",
		"contents": namespace({}, {}),
	}]
}

test_applicationset_with_create_namespace_is_denied if {
	count(kubernetes.deny) == 1 with input as [{
		"path": "gitops/platform/argocd/rendered/kind-local/applicationset-platform.yaml",
		"contents": {
			"kind": "ApplicationSet",
			"spec": {"template": {"spec": {
				"source": {"targetRevision": "main"},
				"syncPolicy": {"syncOptions": ["CreateNamespace=true"]},
			}}},
		},
	}]
}
