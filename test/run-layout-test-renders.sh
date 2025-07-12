#!/bin/bash

base_dir="$(readlink -m "$(dirname "$0")/..")"
output_dir="$base_dir/test-output"
test_dir="$base_dir/test"

echo "base_dir:   $base_dir"
echo "output_dir: $output_dir"
echo "test_dir:   $test_dir"

mkdir -p "$output_dir"

rm -f "$output_dir/degree-of-view-1-yaw-actual.png"
rm -f "$output_dir/degree-of-view-2-yaw-pitch-actual.png"
rm -f "$output_dir/degree-of-view-3-yaw-pitch-rot-actual.png"

rm -f "$output_dir/lens-correction-1-a-actual.png"
rm -f "$output_dir/lens-correction-2-a-b-c-actual.png"


"$base_dir/show-pano-layout.py" -i "$test_dir/degree-of-view-1-yaw.pto" -o "$output_dir/degree-of-view-1-yaw-actual.png" --image-outline-color=red --image-outline-width=3
"$base_dir/show-pano-layout.py" -i "$test_dir/degree-of-view-2-yaw-pitch.pto" -o "$output_dir/degree-of-view-2-yaw-pitch-actual.png" --image-outline-color=red --image-outline-width=3
"$base_dir/show-pano-layout.py" -i "$test_dir/degree-of-view-3-yaw-pitch-rot.pto" -o "$output_dir/degree-of-view-3-yaw-pitch-rot-actual.png" --image-outline-color=red --image-outline-width=3
"$base_dir/show-pano-layout.py" -i "$test_dir/lens-correction-1-a.pto" -o "$output_dir/lens-correction-1-a-actual.png" --image-outline-color=red --image-outline-width=3
"$base_dir/show-pano-layout.py" -i "$test_dir/lens-correction-2-a-b-c.pto" -o "$output_dir/lens-correction-2-a-b-c-actual.png" --image-outline-color=red --image-outline-width=3
