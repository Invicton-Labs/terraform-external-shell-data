# Equivalent of set -e
$ErrorActionPreference = "Stop"

# Equivalent of set -u (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7.1)
set-strictmode -version 3.0

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload
$_stderrfile = $json.stderrfile
$_stdoutfile = $json.stdoutfile

Remove-Item "$_stderrfile" -ErrorAction Ignore
Remove-Item "$_stdoutfile" -ErrorAction Ignore

@{} | ConvertTo-Json
