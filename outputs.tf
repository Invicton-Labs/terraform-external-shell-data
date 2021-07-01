output "stdout" {
  // If it was in Linux, we must replace the magic string with quotes
  value = local.is_windows ? local.stdout : replace(replace(local.stdout, "__TF_MAGIC_QUOTE_STRING", "\""), "__TF_MAGIC_NEWLINE_STRING", "\n")
}

output "stderr" {
  // If it was in Linux, we must replace the magic string with quotes
  value = local.is_windows ? local.stderr : replace(replace(local.stderr, "__TF_MAGIC_QUOTE_STRING", "\""), "__TF_MAGIC_NEWLINE_STRING", "\n")
}

output "exitstatus" {
  value = local.exitcode
}
