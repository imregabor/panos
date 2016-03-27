#!/bin/bash
#
# Prepare smaller panorama which does not wrap around
#
#

set -e
set -o pipefail
set -u

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
for i in nona enblend pto_gen pano_modify cpfind cpclean autooptimiser pto_var vig_optimize convert 
do
    echo "Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done    

if [ -z "$1" ] 
then
    echo "Specify source image"
    exit -1
fi

if [ ! -e "$1" ]
then
    echo "Source image not found $1"
    exit -1
fi

function sect {
    echo | tee -a "${LOG}" ; echo | tee -a "${LOG}" ; echo "+------------------------------------------------------------------------------------------" | tee -a "${LOG}" ; echo "|" | tee -a "${LOG}"
    while [ $# -gt 0 ] ; do echo "| $1" | tee -a "${LOG}"; shift; done
    echo "| "$(date "+%Y-%m-%d %H:%M:%S") | tee -a "${LOG}"
    echo "|" | tee -a "${LOG}" ; echo "+-------------------------------------------------------------------------------------------" | tee -a "${LOG}" ; echo | tee -a "${LOG}" ; echo | tee -a "${LOG}"
}

BN=$(basename "$1" .tif)
BN=$(basename "$BN" .tiff)
BN=$(basename "$BN" .TIF)
BN=$(basename "$BN" .TIFF)
BN=$(basename "$BN" .jpg)
BN=$(basename "$BN" .JPG)
BN=$(basename "$BN" .jpeg)
BN=$(basename "$BN" .JPEG)
BN=$(basename "$BN" .png)
BN=$(basename "$BN" .PNG)


LOG="$BN-export-nadir-shot.log"
PTO="$BN-export-nadir.pto"
OUT="$BN-nadir.tif"

sect "Export nadir shot" \
     "Source image: $1" \
     "Basename:     $BN" \
     "PTO file:     $PTO"
     
pto_gen -p 4 -f 360 -o "$PTO" "$1"     
pano_modify -p 0 --fov=80x80 --canvas=AUTO --rotate=0,90,0 -o "$PTO" "$PTO"

sect "Stitch with nona"

nona -v -o "$BN-nadir" "$PTO" -m TIFF 

sect "DONE"
