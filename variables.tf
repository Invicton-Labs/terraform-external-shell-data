variable "dynamic_depends_on" {
  description = "This input variable has the same function as the `depends_on` built-in variable, but has no restrictions on what kind of content it can contain."
  type        = any
  default     = null
}
locals {
  var_dynamic_depends_on = var.dynamic_depends_on
}

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
  description = "Map of environment variables to pass to the command."
  type        = map(string)
  default     = {}
  validation {
    // Ensure that none of the variable names violate the env var naming rules
    condition = var.environment == null ? true : length([
      for k in keys(var.environment) :
      true
      if length(regexall("^[a-zA-Z_]+[a-zA-Z0-9_]*$", k)) == 0
    ]) == 0
    error_message = "Environment variable names must consist solely of letters, digits, and underscores, and may not start with a digit."
  }
}
locals {
  var_environment = var.environment != null ? var.environment : {}
}

variable "environment_sensitive" {
  description = "Map of sensitive environment variables to pass to the command. If any of these values are detected in the `stdout` or `stderr` outputs, they will be marked as sensitive. These keys/values will be merged with the `environment` input variable (this overwrites those values with the same key)."
  type        = map(string)
  default     = {}
  validation {
    // Ensure that none of the variable names violate the env var naming rules
    condition = var.environment_sensitive == null ? true : length([
      for k in keys(var.environment_sensitive) :
      true
      if length(regexall("^[a-zA-Z_]+[a-zA-Z0-9_]*$", k)) == 0
    ]) == 0
    error_message = "Environment variable names must consist solely of letters, digits, and underscores, and may not start with a digit."
  }
}
locals {
  var_environment_sensitive = var.environment_sensitive != null ? var.environment_sensitive : {}
}

variable "working_dir" {
  description = "The working directory where command will be executed. Defaults to this module's install directory (usually somewhere in the `.terraform` directory)."
  type        = string
  default     = null
}
locals {
  var_working_dir = var.working_dir
}

variable "fail_on_nonzero_exit_code" {
  description = "Whether a Terraform error should be thrown if the command exits with a non-zero exit code. If true, nothing will be returned from this module and Terraform will fail the plan/apply. If false, the error message will be returned in `stderr` and the error code will be returned in `exit_code`."
  type        = bool
  default     = true
}
locals {
  var_fail_on_nonzero_exit_code = var.fail_on_nonzero_exit_code != null ? var.fail_on_nonzero_exit_code : true
}

variable "fail_on_stderr" {
  description = "Whether a Terraform error should be thrown if the command outputs anything to stderr. If true, nothing will be returned from this module and Terraform will fail the plan/apply. If false, the error message will be returned in `stderr` and the exit code will be returned in `exit_code`."
  type        = bool
  default     = false
}
locals {
  var_fail_on_stderr = var.fail_on_stderr != null ? var.fail_on_stderr : false
}

variable "force_wait_for_apply" {
  description = "Whether to force this module to wait for apply-time to execute the shell command. Otherwise, it will run during plan-time if possible (i.e. if all inputs are known during plan time)."
  type        = bool
  default     = false
}
locals {
  var_force_wait_for_apply = var.force_wait_for_apply != null ? var.force_wait_for_apply : false
}

variable "timeout" {
  description = "The maximum number of seconds to allow the shell command to execute for  If it exceeds this timeout, it will be killed and will fail. Leave as the default (`null`) or set as 0 for no timeout."
  type        = number
  default     = null
  validation {
    condition     = var.timeout == null ? true : var.timeout >= 0
    error_message = "The `timeout` input variable, if provided, must be greater than or equal to 0."
  }
}
locals {
  var_timeout = var.timeout == 0 ? null : var.timeout
}

variable "fail_on_timeout" {
  description = "Whether a Terraform error should be thrown if the command times out. If true, nothing will be returned from this module and Terraform will fail the plan/apply. If false, any `stdout` and `stderr` output that was produced before timing out will be returned in their respective outputs, and the `exit_code` output will be `null`."
  type        = bool
  default     = true
}
locals {
  var_fail_on_timeout = var.fail_on_timeout != null ? var.fail_on_timeout : true
}

variable "unix_interpreter" {
  description = "The interpreter to use when running commands on a Unix-based system. This is primarily used for testing, and should usually be left to the default value."
  type        = string
  default     = "/bin/sh"
}
locals {
  var_unix_interpreter = var.unix_interpreter != null ? var.unix_interpreter : "/bin/sh"
}

variable "execution_id" {
  description = "A unique ID for the shell execution. Used for development only and will default to a UUID."
  type        = string
  default     = null
  validation {
    // Ensure that if an execution ID is provided, it matches the regex
    condition     = var.execution_id == null ? true : length(regexall("^[a-zA-Z0-9_. -]+$", trimspace(var.execution_id))) > 0
    error_message = "The `execution_id` input variable, if provided, must consist solely of letters, digits, hyphens, underscores, and spaces, and may not consist entirely of whitespace."
  }
}
locals {
  var_execution_id = var.execution_id
}

variable "suppress_console" {
  description = "Whether to suppress the Terraform console output (including plan content and shell execution status messages) for this module. If enabled, much of the content will be hidden by marking it as \"sensitive\"."
  type        = bool
  default     = true
}
locals {
  var_suppress_console = var.suppress_console != null ? var.suppress_console : false
}
