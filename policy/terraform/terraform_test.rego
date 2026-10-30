package terraform_test

import data.terraform

pinned := {"terraform": [{"required_providers": [{"helm": {"source": "hashicorp/helm", "version": "3.1.1"}}]}]}

test_pinned_provider_in_module_is_allowed if {
	count(terraform.deny) == 0 with input as [{"path": "modules/cluster-kind/terraform.tf", "contents": pinned}]
}

test_range_version_is_denied if {
	contents := {"terraform": [{"required_providers": [{"helm": {"source": "hashicorp/helm", "version": "~> 3.1"}}]}]}
	count(terraform.deny) == 1 with input as [{"path": "modules/cluster-kind/terraform.tf", "contents": contents}]
}

test_missing_version_is_denied if {
	contents := {"terraform": [{"required_providers": [{"helm": {"source": "hashicorp/helm"}}]}]}
	count(terraform.deny) == 1 with input as [{"path": "instances/homelab/terraform.tf", "contents": contents}]
}

test_missing_source_is_denied if {
	contents := {"terraform": [{"required_providers": [{"helm": {"version": "3.1.1"}}]}]}
	count(terraform.deny) == 1 with input as [{"path": "modules/cluster-kind/terraform.tf", "contents": contents}]
}

test_provider_block_in_module_is_denied if {
	contents := {"provider": {"helm": [{}]}}
	count(terraform.deny) == 1 with input as [{"path": "modules/bootstrap-cilium/providers.tf", "contents": contents}]
}

test_provider_block_in_root_is_allowed if {
	contents := {"provider": {"helm": [{}]}}
	count(terraform.deny) == 0 with input as [{"path": "instances/homelab/providers.tf", "contents": contents}]
}
