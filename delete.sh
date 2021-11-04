#!/usr/bin/env bash

set -eu

IFS='"' read -ra JSON <<< $(cat)
_stderrfile=$(echo -n "${JSON[3]}" | sed -e 's/__TF_MAGIC_BACKSLASH_STRING/\\/g' -e $'s/__TF_MAGIC_QUOTE_STRING/\"/g;s/__TF_MAGIC_TAB_STRING/\t/g;s/__TF_MAGIC_LT_STRING/</g;s/__TF_MAGIC_GT_STRING/>/g;s/__TF_MAGIC_AMP_STRING/\&/g;s/__TF_MAGIC_2028_STRING/\u2028/g;s/__TF_MAGIC_2029_STRING/\u2029/g')
_stdoutfile=$(echo -n "${JSON[7]}" | sed -e 's/__TF_MAGIC_BACKSLASH_STRING/\\/g' -e $'s/__TF_MAGIC_QUOTE_STRING/\"/g;s/__TF_MAGIC_TAB_STRING/\t/g;s/__TF_MAGIC_LT_STRING/</g;s/__TF_MAGIC_GT_STRING/>/g;s/__TF_MAGIC_AMP_STRING/\&/g;s/__TF_MAGIC_2028_STRING/\u2028/g;s/__TF_MAGIC_2029_STRING/\u2029/g')

rm -r "$_stderrfile"
rm -r "$_stdoutfile"

echo -n "{}"