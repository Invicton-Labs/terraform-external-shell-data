set -e
if ! [ -z "$BASH" ]; then
    # Only Bash supports this feature
    set -o pipefail
fi
# Set this after checking for the BASH variable
set -u

# This checks if we're running on MacOS
_kernel_name="$(uname -s)"
case "${_kernel_name}" in
    darwin*|Darwin*)    
        # It's MacOS.
        # Mac doesn't support the "-d" flag for base64 decoding, 
        # so we have to use the full "--decode" flag instead.
        _decode_flag="--decode"
        # Mac doesn't support the "-w" flag for base64 wrapping, 
        # and it isn't needed because by default it doens't break lines.
        _wrap_flag="" ;;
    *)
        # It's NOT MacOS.
        # Not all Linux base64 installs (e.g. BusyBox) support the full
        # "--decode" flag. So, we use "-d" here, since it's supported
        # by everything except MacOS.
        _decode_flag="-d"
        # All non-Mac installs need this to be specified to prevent line
        # wrapping, which adds newlines that we don't want.
        _wrap_flag="-w0" ;;
esac

# This checks if the "-n" flag is supported on this shell, and sets vars accordingly
if [ "`echo -n`" = "-n" ]; then
  _echo_n=""
  _echo_c="\c"
else
  _echo_n="-n"
  _echo_c=""
fi

_raw_input="$(cat)"

# We know that all of the inputs are base64-encoded, and "|" is not a valid base64 character, so therefore it
# cannot possibly be included in the stdin.
IFS="|"
set -o noglob
set -- $_raw_input""
_execution_id="$(echo "${2}" | base64 $_decode_flag)"
_directory="$(echo "${3}" | base64 $_decode_flag)"
_environment="$(echo "${4}" | base64 $_decode_flag)"
_timeout="$(echo "${5}" | base64 $_decode_flag)"
_exit_on_nonzero="$(echo "${6}" | base64 $_decode_flag)"
_exit_on_stderr="$(echo "${7}" | base64 $_decode_flag)"
_exit_on_timeout="$(echo "${8}" | base64 $_decode_flag)"
_debug="$(echo "${9}" | base64 $_decode_flag)"
_shell="$(echo "${10}" | base64 $_decode_flag)"
_command_b64="${11}"

# Generate a random/unique ID if an ID wasn't explicitly set
if [ "$_execution_id" = " " ]; then
    # We try many different strategies for generating a random number, hoping that at least one will succeed,
    # since each OS/shell supports a different combination.
    if [ -e /proc/sys/kernel/random/uuid ]; then
        _execution_id="$(cat /proc/sys/kernel/random/uuid)"
    elif [ -e /dev/urandom ]; then
        # Using head instead of cat here seems odd, and it is, but it deals with a pipefail
        # issue on MacOS that occurs if you use cat instead.
        _execution_id="$(head -c 10000 /dev/urandom | LC_ALL=C tr -dc '[:alnum:]' | head -c 40)"
    elif [ -e /dev/random ]; then
        _execution_id="$(head -c 10000 /dev/random | LC_ALL=C tr -dc '[:alnum:]' | head -c 40)"
    else
        _execution_id="$RANDOM-$RANDOM-$RANDOM-$RANDOM"
    fi
fi

# The filenames to direct output to
_stderrfile="$_directory/$_execution_id.stderr"
_stdoutfile="$_directory/$_execution_id.stdout"

# Split the env var input on semicolons. We use semicolons because we know
# that neither the env var name nor the base64-encoded value will contain
# a semicolon.
IFS=";"
set -o noglob
set -- $_environment""
for _env in "$@"; do
    if [ -z "$_env" ]; then
        continue
    fi
    # For each env var, split it on a colon. We use colons because we know
    # that neither the env var name nor the base64-encoded value will contain
    # a colon.
    _key="$(echo $_echo_n "${_env}${_echo_c}" | cut -d':' -f1 | base64 $_decode_flag)"
    _val="$(echo $_echo_n "${_env}${_echo_c}" | cut -d':' -f2 | base64 $_decode_flag)"
    export "$_key"="$_val"
done

# A command to run at the very end of the input script. This forces the script to
# always exit with the exit code of the last command that returned an exit code.
_cmd_suffix=<<EOF
exit $?
EOF

# This is a custom function that executes the command, but interrupts it with a SIGALARM
# if it runs for too long. Not all operating systems have "timeout" built in, so
# we need to have a custom function that simulates it.
perl_timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

# Run the command, but don't exit this script on an error
_timed_out="false"
if [ $_timeout -eq 0 ]; then
    # No timeout is set, so run the command without a timeout
    set +e
    2>"$_stderrfile" >"$_stdoutfile" $_shell -c "$(echo "${_command_b64}" | base64 $_decode_flag)${_cmd_suffix}"
    _exitcode=$?
    set -e
else
    # Add a prefix to the command, which wraps the commands in a block
    _cmd_prefix=<<EOF
{
EOF
    # Extend the suffix after the command, which redirects all stderr to a new descriptor
    # We do this so that when timeout alarm signals cause the shell to print the signal
    # description, it doesn't get captured into the stderr that we actually want.
    _cmd_suffix=<<EOF
$_cmd_suffix
} 2>&3
EOF
    # Default to using the built-in timeout command
    _timeout_cmd="timeout"
    if ! command -v $_timeout_cmd >/dev/null 2>/dev/null; then
        # If it doesn't exist though, use the custom Perl one we created
        _timeout_cmd="perl_timeout"
    fi
    # There is a timeout set, so run the command with it
    set +e
    $_timeout_cmd $_timeout 3>"$_stderrfile" >"$_stdoutfile" $_shell -c "${_cmd_prefix}$(echo "${_command_b64}" | base64 $_decode_flag)${_cmd_suffix}"
    _exitcode=$?
    set -e
    # Check if it timed out. 142 is the exit code from a Perl alarm signal, 124 is the exit code from most built-in 
    # "timeout" commands, and 143 is the exit code from the Busybox "timeout" command.
    if [ $_exitcode -eq 142 ] || [ $_exitcode -eq 124 ] || [ $_exitcode -eq 143 ]; then
        _timed_out="true"
    fi
fi

# Read the stderr and stdout files
_stdout="$(cat "$_stdoutfile")"
_stderr="$(cat "$_stderrfile")"

# Delete the files, unless we're using debug mode
if [ "$_debug" != "true" ]; then
    rm "$_stderrfile"
    rm "$_stdoutfile"
fi

# Check if the execution timed out
if [ "$_timed_out" = "true" ]; then
    if [ "$_exit_on_timeout" = "true" ]; then
        >&2 echo $_echo_n "Execution timed out after $_timeout seconds${_echo_c}"
        exit 1
    else
        _exitcode="null"
    fi
fi

# If we want to kill Terraform on a non-zero exit code and the exit code was non-zero, OR
# we want to kill Terraform on a non-empty stderr and the stderr was non-empty
if ( [ "$_exit_on_nonzero" = "true" ] && [ "$_exitcode" != "null" ] && [ $_exitcode -ne 0 ] ) || ( [ "$_exit_on_stderr" = "true" ] && ! [ -z "$_stderr" ] ); then
    # If there was a stderr, write it out as an error
    if ! [ -z "$_stderr" ]; then
        >&2 echo $_echo_n "${_stderr}${_echo_c}"
    fi

    # If a non-zero exit code was given, exit with it
    if ( [ "$_exitcode" != "null" ] && [ "$_exitcode" -ne 0 ] ); then
        exit $_exitcode
    fi
    # Otherwise, exit with a default non-zero exit code
    exit 1
fi

# Base64-encode the stdout and stderr for transmission back to Terraform
_stdout_b64=$(echo $_echo_n "${_stdout}${_echo_c}" | base64 $_wrap_flag)
_stderr_b64=$(echo $_echo_n "${_stderr}${_echo_c}" | base64 $_wrap_flag)
_exitcode_b64=$(echo $_echo_n "${_exitcode}${_echo_c}" | base64 $_wrap_flag)

# Echo a JSON string that Terraform can parse as the result
echo $_echo_n "{\"stdout\": \"$_stdout_b64\", \"stderr\": \"$_stderr_b64\", \"exitcode\": \"$_exitcode_b64\"}${_echo_c}"
