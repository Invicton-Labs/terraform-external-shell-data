variable "command" {
  description = "(Optional) The command to run on creation when the module is used on a Unix machine."
  default     = null
}

variable "command_windows" {
  description = "(Optional) The command to run on creation when the module is used on a Windows machine. If not specified, will default to be the same as the `command` variable."
  default     = null
}

variable "environment" {
  type        = map(string)
  default     = {}
  description = "(Optional) Map of environment variables to pass to the command."
}

variable "working_dir" {
  type        = string
  default     = ""
  description = "(Optional) The working directory where command will be executed. Default: the directory where the module is created."
}

variable "fail_on_error" {
  type        = bool
  default     = false
  description = "(Optional) Whether a Terraform error should be thrown if the command throws an error. If true, nothing will be returned from this module and Terraform will fail the apply. If false, the error message will be returned in `stderr` and the error code will be returned in `exitcode`. Default: `false`."
}
