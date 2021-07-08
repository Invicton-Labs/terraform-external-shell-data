locals {
  is_windows = dirname("/") == "\\"
  // If command_unix is specified, use it. Otherwise, if command_windows is specified, use it. Otherwise, use a command that does nothing (":")
  // Then replace all quotes in the resulting command with a magic string
  command_unix = replace(replace(replace(chomp(var.command_unix != null ? var.command_unix : (var.command_windows != null ? var.command_windows : ":")), "\"", "__TF_MAGIC_QUOTE_STRING"), "\t", "__TF_MAGIC_TAB_STRING"), "\\", "__TF_MAGIC_BACKSLASH_STRING")
  // If command_windows is specified, use it. Otherwise, if command_unixs is specified, use it. Otherwise, use a command that does nothing ("% ':'")
  command_windows  = chomp(var.command_windows != null ? var.command_windows : (var.command_unix != null ? var.command_unix : "% ':'"))
  temporary_dir    = abspath(path.module)
  interpreter      = local.is_windows ? ["powershell.exe", "${abspath(path.module)}/run.ps1"] : ["${abspath(path.module)}/run.sh"]
  command          = local.is_windows ? local.command_windows : local.command_unix
  command_replaced = replace(replace(replace(replace(replace(local.command, "<", "__TF_MAGIC_LT_STRING"), ">", "__TF_MAGIC_GT_STRING"), "&", "__TF_MAGIC_AMP_STRING"), "\u2028", "__TF_MAGIC_2028_STRING"), "\u2029", "__TF_MAGIC_2029_STRING")
  // Replace each character in the environment values that Terraform's jsonencode tries to replace
  environment = {
    for k, v in var.environment :
    k => replace(replace(replace(replace(replace(v, "<", "__TF_MAGIC_LT_STRING"), ">", "__TF_MAGIC_GT_STRING"), "&", "__TF_MAGIC_AMP_STRING"), "\u2028", "__TF_MAGIC_2028_STRING"), "\u2029", "__TF_MAGIC_2029_STRING")
  }
}

data "external" "run" {
  program = local.interpreter
  query = {
    command     = local.command_replaced
    environment = local.is_windows ? jsonencode(local.environment) : replace(replace(replace(join(";", flatten([for k, v in local.environment : [replace(k, ";", "__TF_MAGIC_SC_STRING"), replace(v, ";", "__TF_MAGIC_SC_STRING")]])), "\"", "__TF_MAGIC_QUOTE_STRING"), "\t", "__TF_MAGIC_TAB_STRING"), "\\", "__TF_MAGIC_BACKSLASH_STRING")
    exitonfail  = var.fail_on_error ? "true" : "false"
    path        = local.is_windows ? local.temporary_dir : replace(local.temporary_dir, "\"", "__TF_MAGIC_QUOTE_STRING")
  }
  working_dir = var.working_dir
}

locals {
  stdout   = chomp(local.is_windows ? data.external.run.result.stdout : replace(replace(replace(replace(replace(data.external.run.result.stdout, "__TF_MAGIC_QUOTE_STRING", "\""), "__TF_MAGIC_NEWLINE_STRING", "\n"), "__TF_MAGIC_CR_STRING", "\r"), "__TF_MAGIC_TAB_STRING", "\t"), "__TF_MAGIC_BACKSLASH_STRING", "\\"))
  stderr   = chomp(local.is_windows ? data.external.run.result.stderr : replace(replace(replace(replace(replace(data.external.run.result.stderr, "__TF_MAGIC_QUOTE_STRING", "\""), "__TF_MAGIC_NEWLINE_STRING", "\n"), "__TF_MAGIC_CR_STRING", "\r"), "__TF_MAGIC_TAB_STRING", "\t"), "__TF_MAGIC_BACKSLASH_STRING", "\\"))
  exitcode = tonumber(chomp(data.external.run.result.exitcode))
}
