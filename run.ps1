# Equivalent of set -e
$ErrorActionPreference = "Stop"

# Equivalent of set -u (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7.1)
set-strictmode -version 3.0

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload

$_execution_id = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.execution_id))
$_directory = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.directory))
$_environment = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.environment))
$_exit_on_nonzero = [System.Convert]::ToBoolean([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_nonzero)))
$_exit_on_stderr = [System.Convert]::ToBoolean([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_stderr)))
$_debug = [System.Convert]::ToBoolean([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.debug)))
$_timeout = [int][System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.timeout))
$_exit_on_timeout = [System.Convert]::ToBoolean([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_timeout)))

# Generate a random/unique ID
if ( "$_execution_id" -eq " " ) {
    $_execution_id = [guid]::NewGuid().ToString()
}
$_cmdfile = "$_directory/$_execution_id.ps1"
$_debugfile = "$_directory/$_execution_id.debug.txt"

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
# This is a function that recursively kills all child processes of a process
function TreeKill([int]$ProcessId) {
    if ($_debug) { Write-Output "Getting process children for $ProcessId" | Out-File -Append -FilePath "$_debugfile" }
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ProcessId } | ForEach-Object { TreeKill -ProcessId $_.ProcessId }
    if ($_debug) { Write-Output "Killing process $ProcessId" | Out-File -Append -FilePath "$_debugfile" }
    $_p = Get-Process -ErrorAction SilentlyContinue -Id $ProcessId
    if ($_p) {
        Stop-Process -Force -Id $ProcessId
        $_p.WaitForExit(10000) | Out-Null
        if (!$_p.HasExited) {
            $_err = "Failed to kill the process after waiting for $_delay seconds:`n$_"
            if ($_debug) { Write-Output "$_err" | Out-File -Append -FilePath "$_debugfile" }
            Write-Error "$_err"
            Exit -1
        }
    }
}

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
$_out_task = $_process.StandardOutput.ReadToEndAsync();
$_err_task = $_process.StandardError.ReadToEndAsync();
$_timed_out = $false
if ([int]$_timeout -eq 0) {
    $_process.WaitForExit() | Out-Null
}
else {
    $_process_result = $_process.WaitForExit($_timeout * 1000)
    if (-Not $_process_result) {
        if ($_debug) { Write-Output "Process timed out, killing..." | Out-File -Append -FilePath "$_debugfile" }
        TreeKill -ProcessId $_process.Id
        $_timed_out = $true
    }
}
$ErrorActionPreference = "Stop"

$_stdout = $_out_task.Result
$_stderr = $_err_task.Result
$_exitcode = $_process.ExitCode

# Delete the command file, unless we're using debug mode,
# in which case we might want to review it for debugging
# purposes.
if ( -not $_debug ) {
    Remove-Item "$_cmdfile"
}

# Check if the execution timed out
if ($_timed_out) {
    # If it did, check if we're supposed to exit the script on a timeout
    if ( $_exit_on_timeout ) {
        $ErrorActionPreference = "Continue"
        Write-Error "Execution timed out after $_timeout seconds"
        $ErrorActionPreference = "Stop"
        Exit -1
    }
    else {
        $_exitcode = "null"
    }
}

# If we want to kill Terraform on a non-zero exit code and the exit code was non-zero, OR
# we want to kill Terraform on a non-empty stderr and the stderr was non-empty
if ((( $_exit_on_nonzero ) -and ($_exitcode -ne 0) -and ($_exitcode -ne "null")) -or (( $_exit_on_stderr ) -and "$_stderr")) {
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
    exitcode = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($_exitcode))
} | ConvertTo-Json