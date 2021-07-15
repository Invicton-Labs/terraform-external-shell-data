# Terraform Shell (Data)

This module provides a wrapper for running shell scripts as data sources (re-run on every plan/apply) and capturing the output. Unlike Terraform's standard [External Data Source](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/data_source), this module supports:
- Environment variables
- Capturing `stdout`, `stderr`, and `exitstatus` of the command
- Built-in support for both Linux and Windows
- Optional Terraform failure when an error in the given command occurs

For a similar module that **runs as a resource** (only re-runs the command on resource re-create or on a change in a trigger), see [this module](https://registry.terraform.io/modules/Invicton-Labs/shell-resource/external/latest) on the Terraform Registry.

# Usage
```
module "shell_data_hello" {
  source  = "Invicton-Labs/shell-data/external"
  command_unix         = "echo \"$TEXT - $MORETEXT\""
  command_windows = "Write-Host \"$env:TEXT - $env:MORETEXT\""
  working_dir     = path.module
  fail_on_error   = true
  environment = {
    TEXT     = "hello world"
    MORETEXT = "goodbye world"
  }
}
output "stdout" {
  value = module.shell-data-hello.stdout
}
output "stderr" {
  value = module.shell-data-hello.stderr
}
output "exitstatus" {
  value = module.shell-data-hello.exitstatus
}
```

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

exitstatus = 0
stderr = ""
stdout = "hello world - goodbye world"
```
