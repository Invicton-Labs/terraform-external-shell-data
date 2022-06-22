# Terraform Shell (Data)

On the Terraform Registry: [Invicton-Labs/shell-data/external](https://registry.terraform.io/modules/Invicton-Labs/shell-data/external/latest)

This module provides a wrapper for running shell scripts as data sources (re-run on every plan/apply) and capturing the output. Unlike Terraform's standard [External Data Source](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/data_source), this module supports:
- Environment variables
- Capturing `stdout`, `stderr`, and `exit_code` of the command
- Built-in support for both Unix and Windows
- Optional Terraform failure when an error in the given command occurs

For Windows, this module should work on any system that supports a relatively modern version of PowerShell. For Unix, this module should work on any POSIX-compatible shell that supports `echo`, `cat`, `cut`, and `base64` (which is the vast majority of out-of-the-box systems).

For a similar module that **runs as a resource** (only re-runs the command on resource re-create or on a change in a trigger), see [this module](https://registry.terraform.io/modules/Invicton-Labs/shell-resource/external/latest) on the Terraform Registry.

## Notes:

1. If only one of `command_unix` or `command_windows` is provided, that one will be used on all operating systems.
2. Carriage returns (`\r`) are removed in all input commands. This is because Powershell doesn't require them to be present, but Unix shells don't support them, so removing them allows the same command to be used on both types of machine.
3. Trailing newlines are trimmed for the `stdout` and `stderr` outputs. This is due to limitations with POSIX-compatible file reading and to ensure consistency between executions of the same Terraform configuration on Windows- and Unix-based machines.

## Usage

```
module "shell_data_hello" {
  source  = "Invicton-Labs/shell-data/external"

  // This is the command that will be run on Unix-based systems
  // If you wanted to, you could use the file() function to read 
  // this command from a local file instead of specifying it as
  // a string.
  command_unix = <<EOF
echo "$TEXT - $MORETEXT"
echo "Env vars can also be multi-line: $MULTILINE_ENV_VAR"
>&2 echo "This is an error"
EOF

  // This is the command that will be run on Windows-based systems
  command_windows = <<EOF
Write-Host "$env:TEXT - $env:MORETEXT"
Write-Host "Env vars can also be multi-line: $env:MULTILINE_ENV_VAR"
Write-Error "This is an error"
EOF

  // Environment variables that will be available for the command.
  // All Terraform environment variables and default shell environment
  // variables will also be available.
  environment = {
    TEXT              = "hello world"
    MORETEXT          = "goodbye world"
    MULTILINE_ENV_VAR = <<EOF

	Env var line 1 (tab-indented)
	Env var line 2 (tab-indented)
EOF
  }

  working_dir = path.module

  // If the command exits with a non-zero exit code, kill Terraform.
  // This is enabled by default because generally we want our commands to succeed.
  fail_on_nonzero_exit_code = true

  // We can optionally also kill Terraform if the command writes anything to stderr.
  // This is disabled by default because many commands write to stderr even if nothing went wrong.
  fail_on_stderr = false

  // We can optionally force it to wait for the apply step before running the command
  // If any of the inputs (command, environment vars) aren't known during the plan step,
  // then it will always wait for apply, regardless of this setting.
  force_wait_for_apply = false
}

output "stdout" {
  value = module.shell_data_hello.stdout
}
output "stderr" {
  value = module.shell_data_hello.stderr
}
output "exit_code" {
  value = module.shell_data_hello.exit_code
}
```

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

exit_code = 0
stderr = "This is an error"
stdout = <<EOT
hello world - goodbye world
Env vars can also be multi-line:
        Env var line 1 (tab-indented)
        Env var line 2 (tab-indented)
EOT
```
