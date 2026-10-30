# Test cases of the instance Terraform check

`mise run schemas:test` runs `check_instance_terraform` (in `.mise/tasks/_base/instance-checks.sh`) on each folder. The task copies each folder to a temporary folder and changes `main.tf.txt` to `main.tf`. The files have the `.txt` extension, because the Terraform linters must not read them.

- `valid/`: the check must pass.
- `invalid/`: the check must fail.
