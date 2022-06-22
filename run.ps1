# Equivalent of set -e
$ErrorActionPreference = "Stop"

# Equivalent of set -u (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7.1)
set-strictmode -version 3.0

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload

$_execution_id = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.execution_id))
$_directory = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.directory))
$_command = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.command))
$_environment = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.environment))
$_exit_on_nonzero = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_nonzero))
$_exit_on_stderr = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.exit_on_stderr))
$_debug = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.debug))

# Generate a random/unique ID
if ( "$_execution_id" -eq " " ) {
    $_execution_id = [guid]::NewGuid().ToString()
}
$_cmdfile = "$_directory/$_execution_id.ps1"
$_stderrfile = "$_directory/$_execution_id.stderr"
$_stdoutfile = "$_directory/$_execution_id.stdout"

# Set the environment variables
$_env_vars = $_environment.Split(";")
foreach ($_env in $_env_vars) {
    if ( "$_env" -eq "" ) {
        continue
    }
    $_env_parts = $_env.Split(":")
    [Environment]::SetEnvironmentVariable($_env_parts[0], [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_env_parts[1])), "Process") 
}

# Write the command to a file
# Always force the command file to exit with the last exit code
[System.IO.File]::WriteAllText("$_cmdfile", "$_command `n`nExit `$LASTEXITCODE")

$ErrorActionPreference = "Continue"
$_process = Start-Process powershell.exe -ArgumentList "-file ""$_cmdfile""" -Wait -PassThru -NoNewWindow -RedirectStandardError "$_stderrfile" -RedirectStandardOutput "$_stdoutfile"
$_exitcode = $_process.ExitCode
$ErrorActionPreference = "Stop"

# Read the stderr and stdout files
$_stdout = [System.IO.File]::ReadAllBytes($_stdoutfile)
$_stderr = [System.IO.File]::ReadAllBytes($_stderrfile)

# Delete the files, unless we're using debug mode
if ( "$_debug" -ne "true" ) {
    Remove-Item "$_cmdfile"
    Remove-Item "$_stderrfile"
    Remove-Item "$_stdoutfile"
}

# If we want to kill Terraform on a non-zero exit code and the exit code was non-zero, OR
# we want to kill Terraform on a non-empty stderr and the stderr was non-empty
if ((( "$_exit_on_nonzero" -eq "true" ) -and $_exitcode) -or (( "$_exit_on_stderr" -eq "true" ) -and "$_stderr")) {
    # If there was a stderr, write it out as an error
    if ("$_stderr") {
        # Since we read the stderr as bytes, convert it to ASCII for display
        $_stderr_string = [System.Text.Encoding]::ASCII.GetString($_stderr)
        # Set continue to not kill the process on writing an error, so we can exit with the desired exit code
        $ErrorActionPreference = "Continue"
        Write-Error "$_stderr_string"
        $ErrorActionPreference = "Stop"
    }
    # If a non-zero exit code was given, exit with it
    if ($_exitcode) {
        exit $_exitcode
    }
    # Otherwise, exit with a default non-zero exit code
    exit 1
}

# Return the outputs as a JSON-encoded string for Terraform to parse
@{
    stderr   = [System.Convert]::ToBase64String($_stderr)
    stdout   = [System.Convert]::ToBase64String($_stdout)
    exitcode = "$_exitcode"
} | ConvertTo-Json
