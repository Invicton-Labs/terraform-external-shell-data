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
  description = "Map of environment variables to pass to the command. Will be merged with `sensitive_environment` (those values will overwrite these values with the same key)."
}

variable "sensitive_environment" {
  type        = map(string)
  default     = {}
  description = "Map of (sentitive) environment variables to pass to the command. Will be merged with `environment` (this overwrites those values with the same key), but will not be shown in the Terraform plan output."
}

variable "working_dir" {
  type        = string
  default     = "./"
  description = "The working directory where command will be executed. Default: the directory where the module is created."
}

variable "fail_on_error" {
  type        = bool
  default     = false
  description = "Whether a Terraform error should be thrown if the command throws an error. If true, nothing will be returned from this module and Terraform will fail the apply. If false, the error message will be returned in `stderr` and the error code will be returned in `exitstatus`. Default: `false`."
}
