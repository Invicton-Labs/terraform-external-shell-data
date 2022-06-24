# Equivalent of set -e
$ErrorActionPreference = "Stop"

# Equivalent of set -u (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7.1)
set-strictmode -version 3.0

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload

$_execution_id = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.execution_id))
$_directory = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.directory))
$_environment = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.environment))
$_exit_on_nonzero = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_nonzero))
$_exit_on_stderr = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_stderr))
$_debug = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.debug))
$_timeout = [int][System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.timeout))
$_exit_on_timeout = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_timeout))

# Generate a random/unique ID
if ( "$_execution_id" -eq " " ) {
    $_execution_id = [guid]::NewGuid().ToString()
}
$_cmdfile = "$_directory/$_execution_id.ps1"

# Set the environment variables
$_env_vars = $_environment.Split(";")
foreach ($_env in $_env_vars) {
    if ( "$_env" -eq "" ) {
        continue
    }
    $_env_parts = $_env.Split(":")
    [Environment]::SetEnvironmentVariable([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_env_parts[0])), [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_env_parts[1])), "Process") 
}

# Write the command to a file
[System.IO.File]::WriteAllText("$_cmdfile", [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.command)))
# Always force the command file to exit with the last exit code
[System.IO.File]::AppendAllText("$_cmdfile", "`nExit `$LASTEXITCODE")

$_pinfo = New-Object System.Diagnostics.ProcessStartInfo
$_pinfo.FileName = "powershell.exe"
$_pinfo.RedirectStandardError = $true
$_pinfo.RedirectStandardOutput = $true
$_pinfo.UseShellExecute = $false
$_pinfo.CreateNoWindow = $false
$_pinfo.Arguments = "-NoProfile -File `"$_cmdfile`""
$_process = New-Object System.Diagnostics.Process
$_process.StartInfo = $_pinfo

$ErrorActionPreference = "Continue"
$_process.Start() | Out-Null  
$outTask = $_process.StandardOutput.ReadToEndAsync();
$errTask = $_process.StandardError.ReadToEndAsync();
$_timed_out = $false
if ([int]$_timeout -eq 0) {
    $_process.WaitForExit()
}
else {
    $_process_result = $_process.WaitForExit($_timeout * 1000)
    if (-Not $_process_result) {
        $_process.Kill();
        $_timed_out = $true
    }
}
$ErrorActionPreference = "Stop"

$_stdout = $outTask.Result
$_stderr = $errTask.Result
$_exitcode = $_process.ExitCode

# Delete the command file, unless we're using debug mode,
# in which case we might want to review it for debugging
# purposes.
if ( "$_debug" -ne "true" ) {
    Remove-Item "$_cmdfile"
}

# Check if the execution timed out
if ($_timed_out) {
    # If it did, check if we're supposed to exit the script on a timeout
    if ( "$_exit_on_timeout" -eq "true" ) {
        $ErrorActionPreference = "Continue"
        Write-Error "Execution timed out after $_timeout seconds"
        $ErrorActionPreference = "Stop"
        exit 1
    }
    else {
        $_exitcode = "null"
    }
}

# If we want to kill Terraform on a non-zero exit code and the exit code was non-zero, OR
# we want to kill Terraform on a non-empty stderr and the stderr was non-empty
if ((( "$_exit_on_nonzero" -eq "true" ) -and ($_exitcode -ne 0) -and ($_exitcode -ne "null")) -or (( "$_exit_on_stderr" -eq "true" ) -and "$_stderr")) {
    # If there was a stderr, write it out as an error
    if ("$_stderr") {
        # Set continue to not kill the process on writing an error, so we can exit with the desired exit code
        $ErrorActionPreference = "Continue"
        Write-Error "$_stderr"
        $ErrorActionPreference = "Stop"
    }
    # If a non-zero exit code was given, exit with it
    if (($_exitcode -ne 0) -and ($_exitcode -ne "null")) {
        exit $_exitcode
    }
    # Otherwise, exit with a default non-zero exit code
    exit 1
}

# Return the outputs as a JSON-encoded string for Terraform to parse
@{
    stderr   = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($_stderr))
    stdout   = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($_stdout))
    exitcode = "$_exitcode"
} | ConvertTo-Json