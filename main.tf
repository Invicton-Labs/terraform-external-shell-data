locals {
  is_windows = dirname("/") == "\\"

  // If `force_wait_for_apply` is set to `true`, this will not return a value
  // until the apply step, thereby forcing the external data to wait for the apply step
  wait_for_apply = var.force_wait_for_apply ? uuid() : null

  # These are commands that have no effect
  null_command_unix    = ":"
  null_command_windows = "% ':'"

  // If command_unix is specified, use it. Otherwise, if command_windows is specified, use it. Otherwise, use a command that does nothing
  command_unix = replace(replace(chomp(var.command_unix != null ? var.command_unix : (var.command_windows != null ? var.command_windows : local.null_command_unix)), "\r", ""), "\r\n", "\n")
  // If command_windows is specified, use it. Otherwise, if command_unixs is specified, use it. Otherwise, use a command that does nothing
  command_windows = chomp(var.command_windows != null ? var.command_windows : (var.command_unix != null ? var.command_unix : local.null_command_windows))

  // Select the command based on the operating system
  command = local.is_windows ? local.command_windows : local.command_unix

  // The directory where temporary files should be stored
  temporary_dir = abspath("${path.module}/tmpfiles")

  // A magic string that we use as a separator. It contains a UUID, so in theory, should
  // be a globally unique ID that will never appear in input content
  unix_query_separator = "__59077cc7e1934758b19d469c410613a7_TF_MAGIC_SEGMENT_SEPARATOR"

  // Generate the environment variable file
  env_file_content = join(";", [
    for k, v in var.environment :
    "${k}:${base64encode(v)}"
  ])
}

// Run the command
data "external" "run" {
  program = local.is_windows ? ["powershell.exe", "${abspath(path.module)}/run.ps1"] : ["/bin/sh", "${abspath(path.module)}/run.sh"]
  // Mark the query as sensitive just so it doesn't show up in the plan output.
  // Since it's all base64-encoded anyways, showing it in the plan wouldn't be useful
  query = sensitive(local.is_windows ? {
    // If it's Windows, use the query parameter normally since PowerShell can natively handle JSON decoding
    directory       = base64encode(local.temporary_dir)
    command         = base64encode(local.command)
    environment     = base64encode(local.env_file_content)
    exit_on_nonzero = base64encode(var.fail_on_nonzero_exit_code ? "true" : "false")
    exit_on_stderr  = base64encode(var.fail_on_stderr ? "true" : "false")

    } : {
    // If it's Unix, use base64-encoded strings with a special separator that we can easily use to separate in shell, 
    // without needing to install jq
    "" = join("", [local.unix_query_separator, join(local.unix_query_separator, [
      base64encode(local.temporary_dir),
      base64encode("${local.command}\n${local.is_windows ? "Exit $LASTEXITCODE" : "exit $?"}"),
      base64encode(local.env_file_content),
      base64encode(var.fail_on_nonzero_exit_code ? "true" : "false"),
      base64encode(var.fail_on_stderr ? "true" : "false")
    ]), local.unix_query_separator])
  })
  working_dir = local.wait_for_apply == null ? var.working_dir : var.working_dir
}

locals {
  stderr   = chomp(base64decode(data.external.run.result.stderr))
  stdout   = chomp(base64decode(data.external.run.result.stdout))
  exitcode = tonumber(trimspace(data.external.run.result.exitcode))
}
