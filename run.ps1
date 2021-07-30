# Equivalent of set -e
$ErrorActionPreference = "Stop"

# Equivalent of set -u (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7.1)
set-strictmode -version 3.0

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload
$_command = $json.command.Replace("__TF_MAGIC_LT_STRING", "<").Replace("__TF_MAGIC_GT_STRING", ">").Replace("__TF_MAGIC_AMP_STRING", "&").Replace("__TF_MAGIC_2028_STRING", "$([char]0x2028)").Replace("__TF_MAGIC_2029_STRING", "$([char]0x2029)")
$_environment = ConvertFrom-Json $json.environment
$_exitonfail = $json.exitonfail
$_path = $json.path

# Set a random that corresponds to the same limit as linux's $RANDOM
$_id = [guid]::NewGuid().ToString()
$_stderrfile = "$_path/stderr.$_id"
$_stdoutfile = "$_path/stdout.$_id"

foreach ($env in $_environment.PSObject.Properties) {
    [Environment]::SetEnvironmentVariable($env.Name, $env.Value.Replace("__TF_MAGIC_LT_STRING", "<").Replace("__TF_MAGIC_GT_STRING", ">").Replace("__TF_MAGIC_AMP_STRING", "&").Replace("__TF_MAGIC_2028_STRING", "$([char]0x2028)").Replace("__TF_MAGIC_2029_STRING", "$([char]0x2029)"), "Process") 
}

$ErrorActionPreference = "Continue"
$_process = Start-Process powershell.exe -ArgumentList "$_command" -Wait -PassThru -NoNewWindow -RedirectStandardError "$_stderrfile" -RedirectStandardOutput "$_stdoutfile"
$_exitcode = $_process.ExitCode
$ErrorActionPreference = "Stop"

$_stderr = [IO.File]::ReadAllText("$_stderrfile")

if (( "$_exitonfail" -eq "true" ) -and $_exitcode) {
    if ("$_stderr") {
        Write-Error "$_stderr"
    }
    exit $_exitcode
}

@{
    stderrfile = "$_stderrfile"
    stdoutfile = "$_stdoutfile"
    exitcode   = "$_exitcode"
} | ConvertTo-Json
