//==================================================
//     Outputs that match the input variables
//==================================================
output "dynamic_depends_on" {
  description = "The value of the `dynamic_depends_on` input variable."
  value       = local.var_dynamic_depends_on
}
output "command_unix" {
  description = "The value of the `command_unix` input variable, or the default value if the input was `null`, with all carriage returns removed."
  value       = local.command_unix
}
output "command_windows" {
  description = "The value of the `command_windows` input variable, or the default value if the input was `null`, with all carriage returns removed."
  value       = local.command_windows
}
output "environment" {
  description = "The value of the `environment` input variable, or the default value if the input was `null`, with all carriage returns removed."
  value       = local.env_vars
}
output "working_dir" {
  description = "The value of the `working_dir` input variable."
  value       = local.var_working_dir
}
output "fail_on_nonzero_exit_code" {
  description = "The value of the `fail_on_nonzero_exit_code` input variable, or the default value if the input was `null`."
  value       = local.var_fail_on_nonzero_exit_code
}
output "fail_on_stderr" {
  description = "The value of the `fail_on_stderr` input variable, or the default value if the input was `null`."
  value       = local.var_fail_on_stderr
}
output "force_wait_for_apply" {
  description = "The value of the `force_wait_for_apply` input variable, or the default value if the input was `null`."
  value       = local.var_force_wait_for_apply
}
output "timeout" {
  description = "The value of the `timeout` input variable."
  value       = local.var_timeout
}
output "fail_on_timeout" {
  description = "The value of the `fail_on_timeout` input variable, or the default value if the input was `null`."
  value       = local.var_fail_on_timeout
}
output "unix_interpreter" {
  description = "The value of the `unix_interpreter` input variable, or the default value if the input was `null`."
  value       = local.var_unix_interpreter
}

//==================================================
//       Outputs generated by this module
//==================================================
output "stdout" {
  description = "The stdout output of the shell command, with all carriage returns and trailing newlines removed."
  value       = local.stdout_censored
}
output "stderr" {
  description = "The stderr output of the shell command, with all carriage returns and trailing newlines removed."
  value       = local.stderr_censored
}
output "exit_code" {
  description = "The exit status code of the shell command. If the `timeout` input variable was provided and the command timed out, this will be `null`."
  value       = local.exitcode
}
