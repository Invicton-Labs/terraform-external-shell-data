set -euo pipefail

# We know that all of the inputs are base64-encoded, and "|" is not a valid base64 character, so therefore it
# cannot possibly be included in the stdin.
IFS="|" read -a PARAMS <<< $(cat | sed -e 's/__59077cc7e1934758b19d469c410613a7_TF_MAGIC_SEGMENT_SEPARATOR/|/g')

_directory=$(echo "${PARAMS[1]}" | base64 --decode)
_command=$(echo "${PARAMS[2]}" | base64 --decode)
_environment=$(echo "${PARAMS[3]}" | base64 --decode)
_exit_on_nonzero=$(echo "${PARAMS[4]}" | base64 --decode)
_exit_on_stderr=$(echo "${PARAMS[5]}" | base64 --decode)

# Generate a random/unique ID
_id="$RANDOM-$RANDOM-$RANDOM-$RANDOM"
_cmdfile="$_directory/$_id.sh"
_stderrfile="$_directory/$_id.stderr"
_stdoutfile="$_directory/$_id.stdout"

# Split the env var input on semicolons. We use semicolons because we know
# that neither the env var name nor the base64-encoded value will contain
# a semicolon.
IFS=';' read -ra ENVRNMT <<< "$_environment"
for _env in "${ENVRNMT[@]}"; do
    if [ -z "$_env" ]; then
        continue
    fi
    # For each env var, split it on a colon. We use colons because we know
    # that neither the env var name nor the base64-encoded value will contain
    # a colon.
	IFS=':' read -ra ENVRNMT_PARTS <<< "$_env"
    _key="${ENVRNMT_PARTS[0]}"
    _val=$(echo "${ENVRNMT_PARTS[1]}" | base64 --decode)
    export "$_key"="$_val"
done

# Write the command to a file
echo -e "$_command" > "$_cmdfile"

# Always force the command file to exit with the last exit code
echo 'exit $?' >> "$_cmdfile"

set +e
    2>"$_stderrfile" >"$_stdoutfile" bash "$_cmdfile"
    _exitcode=$?
set -e

# Read the stderr and stdout files
_stdout=$(cat "$_stdoutfile")
_stderr=$(cat "$_stderrfile")

# Delete the files
rm "$_cmdfile"
rm "$_stderrfile"
rm "$_stdoutfile"

# If we want to kill Terraform on a non-zero exit code and the exit code was non-zero, OR
# we want to kill Terraform on a non-empty stderr and the stderr was non-empty
if ( [ "$_exit_on_nonzero" = "true" ] && [ $_exitcode -ne 0 ] ) || ( [ "$_exit_on_stderr" = "true" ] && ! [ -z "$_stderr" ] ); then
    # If there was a stderr, write it out as an error
    if ! [ -z "$_stderr" ]; then
        >&2 echo "$_stderr"
    fi

    # If a non-zero exit code was given, exit with it
    if [ $_exitcode -ne 0 ]; then
        exit $_exitcode
    fi
    # Otherwise, exit with a default non-zero exit code
    exit 1
fi

# Base64-encode the stdout and stderr for transmission back to Terraform
_stdout_b64=$(echo -n "$_stdout" | base64 --wrap 0)
_stderr_b64=$(echo -n "$_stderr" | base64 --wrap 0)

# Echo a JSON string that Terraform can parse as the result
echo -n "{\"stdout\": \"$_stdout_b64\", \"stderr\": \"$_stderr_b64\", \"exitcode\": \"$_exitcode\"}"
