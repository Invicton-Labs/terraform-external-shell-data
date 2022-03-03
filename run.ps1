# Equivalent of set -e
$ErrorActionPreference = "Stop"

# Equivalent of set -u (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7.1)
set-strictmode -version 3.0

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload
$_environment = ConvertFrom-Json $json.environment
$_exitonfail = $json.exitonfail
$_path = $json.path

# Set a random that corresponds to the same limit as linux's $RANDOM
$_id = [guid]::NewGuid().ToString()
$_stderrfile = "$_path/stderr.$_id"
$_stdoutfile = "$_path/stdout.$_id"
$_cmdfile = "$_path/cmd.$_id.ps1"

# Write the command to a file to execute from
# First start with a command that causes the script to exit if an error is thrown
Write-Output '$ErrorActionPreference = "Stop"' | Out-File -FilePath "$_cmdfile"
# Now write the command itself 
$json.command.Replace("__TF_MAGIC_LT_STRING", "<").Replace("__TF_MAGIC_GT_STRING", ">").Replace("__TF_MAGIC_AMP_STRING", "&").Replace("__TF_MAGIC_2028_STRING", "$([char]0x2028)").Replace("__TF_MAGIC_2029_STRING", "$([char]0x2029)") | Out-File -Append -FilePath "$_cmdfile"

foreach ($env in $_environment.PSObject.Properties) {
    [Environment]::SetEnvironmentVariable($env.Name, $env.Value.Replace("__TF_MAGIC_LT_STRING", "<").Replace("__TF_MAGIC_GT_STRING", ">").Replace("__TF_MAGIC_AMP_STRING", "&").Replace("__TF_MAGIC_2028_STRING", "$([char]0x2028)").Replace("__TF_MAGIC_2029_STRING", "$([char]0x2029)"), "Process") 
}

$ErrorActionPreference = "Continue"
$_process = Start-Process powershell.exe -ArgumentList "-file ""$_cmdfile""" -Wait -PassThru -NoNewWindow -RedirectStandardError "$_stderrfile" -RedirectStandardOutput "$_stdoutfile"
$_exitcode = $_process.ExitCode
$ErrorActionPreference = "Stop"

# Delete the command file
Remove-Item "$_cmdfile"

# Read the error content from the error file
$_stderr = [IO.File]::ReadAllText("$_stderrfile")

# If we want to kill Terraform on a failure, and there was a non-zero exit code, write the error out
if (( "$_exitonfail" -eq "true" ) -and $_exitcode) {
    # Since we're exiting with an error code, we don't need to read the output files in the Terraform config,
    # and we won't get a chance to delete them via Terraform, so delete them now
    Remove-Item "$_stderrfile" -ErrorAction Ignore
    Remove-Item "$_stdoutfile" -ErrorAction Ignore
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
