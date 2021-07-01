# Equivalent of set -e
$ErrorActionPreference = "Stop"

# Equivalent of set -u (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7.1)
set-strictmode -version 3.0

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload
$_command = $json.command
$_environment = $json.environment
$_exitonfail = $json.exitonfail
$_path = $json.path

# Set a random that corresponds to the same limit as linux's $RANDOM
$_id = Get-Random -Maximum 32767
$_stderrfile = "$_path/stderr.$_id"
$_stdoutfile = "$_path/stdout.$_id"

$_ENVRMT = $_environment.Split(";")
if ($_ENVRMT.Count -gt 1) {
    for (($i = 0); $i -lt $_ENVRMT.Count; $i += 2) {
        [Environment]::SetEnvironmentVariable($_ENVRMT[$i], $_ENVRMT[$i + 1], "Process")
    }
}

$ErrorActionPreference = "Continue"
$_process = Start-Process powershell.exe -ArgumentList "$_command" -Wait -PassThru -NoNewWindow -RedirectStandardError "$_stderrfile" -RedirectStandardOutput "$_stdoutfile"
$_exitcode = $_process.ExitCode
$ErrorActionPreference = "Stop"

$_stderr = [IO.File]::ReadAllText("$_stderrfile")
$_stdout = [IO.File]::ReadAllText("$_stdoutfile")

Remove-Item "$_stderrfile"
Remove-Item "$_stdoutfile"

if (( "$_exitonfail" -eq "true" ) -and $_exitcode) {
    Write-Error "$_stderr"
    exit $_exitcode
}

@{
    stderr   = "$_stderr"
    stdout   = "$_stdout"
    exitcode = "$_exitcode"
} | ConvertTo-Json
