output "stdout" {
  // If it was in Linux, we must replace the magic string with quotes
  value = local.stdout
}

output "stderr" {
  // If it was in Linux, we must replace the magic string with quotes
  value = local.stderr
}

output "exitstatus" {
  value = local.exitcode
}
