locals {
  is_windows = dirname("/") == "\\"

  // If `force_wait_for_apply` is set to `true`, this will not return a value
  // until the apply step, thereby forcing the external data to wait for the apply step
  wait_for_apply = local.var_force_wait_for_apply ? uuid() : null

  # These are commands that have no effect
  null_command_unix    = ":"
  null_command_windows = "% ':'"

  // If command_unix is specified, use it. Otherwise, if command_windows is specified, use it. Otherwise, use a command that does nothing
  command_unix = replace(replace(chomp(local.var_command_unix != null ? local.var_command_unix : (local.var_command_windows != null ? local.var_command_windows : local.null_command_unix)), "\r", ""), "\r\n", "\n")
  // If command_windows is specified, use it. Otherwise, if command_unix is specified, use it. Otherwise, use a command that does nothing
  command_windows = chomp(local.var_command_windows != null ? local.var_command_windows : (local.var_command_unix != null ? local.var_command_unix : local.null_command_windows))

  // Select the command based on the operating system
  command = local.is_windows ? local.command_windows : local.command_unix

  // The directory where temporary files should be stored
  temporary_dir = abspath("${path.module}/tmpfiles")

  // A magic string that we use as a separator. It contains a UUID, so in theory, should
  // be a globally unique ID that will never appear in input content
  unix_query_separator = "|"

  // Generate the environment variable file
  env_file_content = join(";", [
    for k, v in local.var_environment :
    "${base64encode(k)}:${base64encode(v)}"
  ])

  is_debug     = local.var_execution_id != null
  execution_id = local.var_execution_id != null ? local.var_execution_id : " "

  query = {
    // If it's Windows, use the query parameter normally since PowerShell can natively handle JSON decoding
    execution_id    = base64encode(local.execution_id)
    directory       = base64encode(local.temporary_dir)
    command         = base64encode(local.command)
    environment     = base64encode(local.env_file_content)
    exit_on_nonzero = base64encode(local.var_fail_on_nonzero_exit_code ? "true" : "false")
    exit_on_stderr  = base64encode(local.var_fail_on_stderr ? "true" : "false")
    debug           = base64encode(local.is_debug ? "true" : "false")
  }
}

// Run the command
data "external" "run" {
  program = local.is_windows ? ["powershell.exe", "${abspath(path.module)}/run.ps1"] : [local.var_unix_interpreter, "${abspath(path.module)}/run.sh"]
  // Mark the query as sensitive just so it doesn't show up in the plan output.
  // Since it's all base64-encoded anyways, showing it in the plan wouldn't be useful
  query = sensitive(local.is_windows ? local.query : {
    // If it's Unix, use base64-encoded strings with a special separator that we can easily use to separate in shell, 
    // without needing to install jq
    "" = join("", [local.unix_query_separator, join(local.unix_query_separator, [
      local.query.execution_id,
      local.query.directory,
      local.query.command,
      local.query.environment,
      local.query.exit_on_nonzero,
      local.query.exit_on_stderr,
      local.query.debug,
      base64encode(local.var_unix_interpreter),
    ]), local.unix_query_separator])
  })
  working_dir = local.wait_for_apply == null ? local.var_working_dir : local.var_working_dir
}

locals {
  stderr   = trimsuffix(trimsuffix(base64decode(data.external.run.result.stderr), "\r\n"), "\n")
  stdout   = trimsuffix(trimsuffix(base64decode(data.external.run.result.stdout), "\r\n"), "\n")
  exitcode = tonumber(trimspace(data.external.run.result.exitcode))
}
