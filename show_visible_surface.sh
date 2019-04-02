#!/usr/bin/env bash
# vim: ts=2 sw=2 et filetype=sh

#set -e
#set -x

V=${V:-1}

device="${device:-rpi}"
lmc="ssh ${device} -- LayerManagerControl"
visib_regex='visibility:\s\+1$'
tmp=$(mktemp)
l=()

${lmc} get surfaces | tail +2 > $tmp
test -r $tmp || { "Error: Failed to get surfaces list!">&2; exit 1; }

while read -r line; do
  id=$(cut -d' ' -f3 <<<${line})
  test -n "$id" || continue
  l+=( "$id" )
done < $tmp

for id in ${l[@]}; do
  ((id > 10)) || continue
  details=$($lmc get surface "$id")
  if grep -q $visib_regex <<<${details}; then
    if (( V )); then
      echo "$details"
    else
      echo "$id"
    fi
  fi
done

