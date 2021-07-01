variable "depends" {
  description = "Equivalent to the `depends_on` input for a data/resource."
  default     = []
}

variable "command" {
  description = "The command to run on creation when the module is used on a Unix machine."
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
  description = "(Optional) The working directory where command will be executed."
}

variable "fail_on_err" {
  type        = bool
  default     = false
  description = "(Optional) Whether to fail (exit Terraform) on any stderr output."
}
