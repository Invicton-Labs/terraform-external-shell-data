locals {
  is_windows      = dirname("/") == "\\"
  command_windows = var.command_windows != null ? var.command_windows : var.command
  command_chomped = chomp(local.is_windows ? local.command_windows : var.command)
  temporary_dir   = abspath(path.module)
  interpreter     = local.is_windows ? ["powershell.exe", "${abspath(path.module)}/run.ps1"] : ["${abspath(path.module)}/run.sh"]
}

data "external" "run" {
  program = local.interpreter
  query = {
    command     = local.is_windows ? local.command_chomped : replace(local.command_chomped, "\"", "__TF_MAGIC_QUOTE_STRING")
    environment = join(";", flatten([for k, v in var.environment : [local.is_windows ? k : replace(k, ";", "__TF_MAGIC_ENV_SEPARATOR"), local.is_windows ? v : replace(v, ";", "__TF_MAGIC_ENV_SEPARATOR")]]))
    exitonfail  = var.fail_on_error ? "true" : "false"
    path        = local.temporary_dir
  }
  working_dir = var.working_dir
}

locals {
  stdout   = chomp(local.is_windows ? data.external.run.result.stdout : replace(replace(data.external.run.result.stdout, "__TF_MAGIC_QUOTE_STRING", "\""), "__TF_MAGIC_NEWLINE_STRING", "\n"))
  stderr   = chomp(local.is_windows ? data.external.run.result.stderr : replace(replace(data.external.run.result.stderr, "__TF_MAGIC_QUOTE_STRING", "\""), "__TF_MAGIC_NEWLINE_STRING", "\n"))
  exitcode = tonumber(chomp(data.external.run.result.exitcode))
}
