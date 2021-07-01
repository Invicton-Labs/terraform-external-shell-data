#!/usr/bin/env bash

set -eu

IFS='"' read -ra JSON <<< $(cat)
_command=$(echo -n "${JSON[3]}" | sed -e 's/__TF_MAGIC_QUOTE_STRING/\"/g')
_environment=$(echo -n "${JSON[7]}" | sed -e 's/__TF_MAGIC_QUOTE_STRING/\"/g')
_exitonfail=$(echo -n "${JSON[11]}" | sed -e 's/__TF_MAGIC_QUOTE_STRING/\"/g')
_path=$(echo -n "${JSON[15]}" | sed -e 's/__TF_MAGIC_QUOTE_STRING/\"/g')

_id=$RANDOM
_stderrfile="$_path/stderr.$_id"
_stdoutfile="$_path/stdout.$_id"

IFS=';' read -ra ENVRNMT <<< "$_environment"
for ((i=0; i<${#ENVRNMT[@]}; i+=2)); do
    _key=$(echo -n "${ENVRNMT[$i]}" | sed -e 's/__TF_MAGIC_ENV_SEPARATOR/;/g')
    _val=$(echo -n "${ENVRNMT[$(($i+1))]}" | sed -e 's/__TF_MAGIC_ENV_SEPARATOR/;/g')
    export "$_key"="$_val"
done

set +e
    2>"$_stderrfile" >"$_stdoutfile" sh -c "$_command"
    _exitcode=$?
set -e

_stderr=$(cat "$_stderrfile")
_stdout=$(cat "$_stdoutfile")

rm "$_stderrfile"
rm "$_stdoutfile"

if [ "$_exitonfail" = "true" ] && [ $_exitcode -ne 0 ] ; then
    >&2 echo "$_stderr"
    exit $_exitcode
fi

# Replace characters that can't be handled in JSON
_stderr=$(echo "$_stderr" | sed -z 's/\n/__TF_MAGIC_NEWLINE_STRING/g;s/\"/__TF_MAGIC_QUOTE_STRING/g')
_stdout=$(echo "$_stdout" | sed -z 's/\n/__TF_MAGIC_NEWLINE_STRING/g;s/\"/__TF_MAGIC_QUOTE_STRING/g')

echo -n "{\"stderr\": \"$_stderr\", \"stdout\": \"$_stdout\", \"exitcode\": \"$_exitcode\"}"
