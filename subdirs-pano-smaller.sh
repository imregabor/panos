#!/bin/bash
#
# Find all immediate child directories from the current location
# and invoke pano-smaller.sh in all of them.
#
find -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
    (cd "$dir" && "$(dirname "$0")/pano-smaller.sh" "$@")
done
