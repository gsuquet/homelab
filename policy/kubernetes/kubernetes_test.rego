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
