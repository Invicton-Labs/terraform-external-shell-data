variable "command_unix" {
  description = "The command to run on creation when the module is used on a Unix machine. If not specified, will default to be the same as the `command_windows` variable."
  type        = string
  default     = null
}

variable "command_windows" {
  description = "The command to run on creation when the module is used on a Windows machine. If not specified, will default to be the same as the `command_unix` variable."
  type        = string
  default     = null
}

variable "environment" {
  type        = map(string)
  default     = {}
  description = "Map of environment variables to pass to the command."
  validation {
    // Ensure that none of the variable names violate the env var naming rules
    condition = length([
      for k in keys(var.environment) :
      true
      if length(regexall("^[A-Z_]+[A-Z0-9_]*$", k)) == 0
    ]) == 0
    error_message = "Environment variable names must consist solely of uppercase letters, digits, and underscores, and may not start with a digit."
  }
}

variable "working_dir" {
  type        = string
  default     = "./"
  description = "The working directory where command will be executed. Defaults to this module's install directory (usually somewhere in the `.terraform` directory)."
}

variable "fail_on_nonzero_exit_code" {
  type        = bool
  default     = true
  description = "Whether a Terraform error should be thrown if the command exits with a non-zero exit code. If true, nothing will be returned from this module and Terraform will fail the plan/apply. If false, the error message will be returned in `stderr` and the error code will be returned in `exit_code`."
}

variable "fail_on_stderr" {
  type        = bool
  default     = false
  description = "Whether a Terraform error should be thrown if the command outputs anything to stderr. If true, nothing will be returned from this module and Terraform will fail the plan/apply. If false, the error message will be returned in `stderr` and the exit code will be returned in `exit_code`."
}

variable "force_wait_for_apply" {
  description = "Whether to force this module to wait for apply-time to execute the shell command. Otherwise, it will run during plan-time if possible (i.e. if all inputs are known during plan time)."
  type        = bool
  default     = false
}
