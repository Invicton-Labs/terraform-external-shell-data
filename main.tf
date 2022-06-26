locals {
  is_windows = dirname("/") == "\\"

  // If `force_wait_for_apply` is set to `true`, this will not return a value
  // until the apply step, thereby forcing the external data to wait for the apply step
  wait_for_apply = "${local.var_force_wait_for_apply ? uuid() : ""}${jsonencode(local.var_dynamic_depends_on) == "" ? "" : ""}"

  # These are commands that have no effect
  null_command_unix    = ":"
  null_command_windows = "% ':'"

  // If command_unix is specified, use it. Otherwise, if command_windows is specified, use it. Otherwise, use a command that does nothing
  command_unix = replace(replace(chomp(var.command_unix != null ? var.command_unix : (var.command_windows != null ? var.command_windows : local.null_command_unix)), "\r", ""), "\r\n", "\n")
  // If command_windows is specified, use it. Otherwise, if command_unix is specified, use it. Otherwise, use a command that does nothing
  command_windows = replace(replace(chomp(var.command_windows != null ? var.command_windows : (var.command_unix != null ? var.command_unix : local.null_command_windows)), "\r", ""), "\r\n", "\n")

  // Select the command based on the operating system
  // Add the appropriate command to exit with the last exit code
  command = local.is_windows ? local.command_windows : local.command_unix
  // The directory where temporary files should be stored
  temporary_dir = abspath("${path.module}/tmpfiles")

  // Remove any carriage returns from the env vars
  env_vars = {
    for k, v in merge(local.var_environment, local.var_environment_sensitive) :
    k => replace(replace(v, "\r", ""), "\r\n", "\n")
  }

  // Generate the environment variable file
  env_file_content = join(";", [
    for k, v in local.env_vars :
    "${base64encode(k)}:${base64encode(v)}"
  ])

  is_debug     = local.var_execution_id != null
  execution_id = local.var_execution_id != null ? local.var_execution_id : " "

  query_windows = {
    // If it's Windows, use the query parameter normally since PowerShell can natively handle JSON decoding
    execution_id    = base64encode(local.execution_id)
    directory       = base64encode(local.temporary_dir)
    command         = base64encode(local.command)
    environment     = base64encode(local.env_file_content)
    timeout         = base64encode(local.var_timeout == null ? 0 : local.var_timeout)
    exit_on_nonzero = base64encode(local.var_fail_on_nonzero_exit_code ? "true" : "false")
    exit_on_stderr  = base64encode(local.var_fail_on_stderr ? "true" : "false")
    exit_on_timeout = base64encode(local.var_fail_on_timeout ? "true" : "false")
    debug           = base64encode(local.is_debug ? "true" : "false")
  }
  query = local.is_windows ? local.query_windows : {
    // If it's Unix, use base64-encoded strings with a special separator that we can easily use to separate in shell, 
    // without needing to install jq. The "|" character will never be found in base64-encoded content and it doesn't
    // need to be escaped, so it's a good option.
    "" = join("|", [
      "",
      local.query_windows.execution_id,
      local.query_windows.directory,
      local.query_windows.command,
      local.query_windows.environment,
      local.query_windows.timeout,
      local.query_windows.exit_on_nonzero,
      local.query_windows.exit_on_stderr,
      local.query_windows.exit_on_timeout,
      local.query_windows.debug,
      base64encode(local.var_unix_interpreter),
      ""
    ])
  }
}

// Run the command
data "external" "run" {
  program = local.is_windows ? ["powershell.exe", "${abspath(path.module)}/run.ps1"] : [local.var_unix_interpreter, "${abspath(path.module)}/run.sh"]
  // Mark the query as sensitive just so it doesn't show up in the plan output.
  // Since it's all base64-encoded anyways, showing it in the plan wouldn't be useful
  // We want to support older versions of TF that don't have the sensitive function though,
  // so fall back to not marking it as sensitive.
  query       = local.is_debug ? local.query : try(sensitive(local.query), local.query)
  working_dir = local.wait_for_apply == "" ? local.var_working_dir : local.var_working_dir
}

locals {
  // Replace all "\r\n" (considered by Terraform to be a single character) with "\n", and remove any extraneous "\r".
  // This helps ensure a consistent output across platforms.
  stderr = trimsuffix(replace(replace(base64decode(data.external.run.result.stderr), "\r", ""), "\r\n", "\n"), "\n")
  stdout = trimsuffix(replace(replace(base64decode(data.external.run.result.stdout), "\r", ""), "\r\n", "\n"), "\n")
  // This checks if the stderr/stdout contains any of the values of the `environment_sensitive` input variable.
  // We use `replace` to check for the presence, even though the recommended tool is `regexall`, because
  // we don't control what the search string is, so it could be a regex pattern, but we want to treat
  // it as a literal.
  stderr_contains_sensitive = length([
    for k, v in local.var_environment_sensitive :
    true
    if length(replace(local.stderr, v, "")) != length(local.stderr)
  ]) > 0
  stdout_contains_sensitive = length([
    for k, v in local.var_environment_sensitive :
    true
    if length(replace(local.stdout, v, "")) != length(local.stdout)
  ]) > 0
  // The `try` is to support versions of Terraform that don't support `sensitive`.
  stderr_censored = local.stderr_contains_sensitive ? try(sensitive(local.stderr), local.stderr) : local.stderr
  stdout_censored = local.stdout_contains_sensitive ? try(sensitive(local.stdout), local.stdout) : local.stdout
  exitcode_str    = trimspace(replace(replace(base64decode(data.external.run.result.exitcode), "\r", ""), "\r\n", "\n"))
  exitcode        = local.exitcode_str == "null" ? null : tonumber(local.exitcode_str)
}
