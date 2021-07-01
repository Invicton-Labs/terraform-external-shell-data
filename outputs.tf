output "stdout" {
  value = chomp(data.external.run.result.stdout)
}

output "stderr" {
  value = chomp(data.external.run.result.stderr)
}

output "exitstatus" {
  value = tonumber(chomp(data.external.run.result.exitcode))
}
