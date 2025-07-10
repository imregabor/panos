#!/bin/bash
#
# Find all immediate child directories from the current location
# and invoke pano-smaller.sh in all of them.
#
# Directories will be travesed from smaller to larger
# see https://unix.stackexchange.com/questions/106330/sort-all-directories-based-on-their-size
#

echo
echo
echo "Directories to traverse:"
echo

du -sh -- */ | sort -h

echo
echo
echo

du -s -- */ | sort -n | cut -f2 | while read -r dir; do
  (cd "$dir" && "$(dirname "$0")/pano-smaller.sh" "$@")
done
