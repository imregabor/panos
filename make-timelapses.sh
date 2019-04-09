#!/bin/bash

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found"; exit 1; }



if [ -z "$1" ]; then
    echo "Input file name missing. Exiting."
    exit -1
fi
 

dn=${PWD##*/}
if [[ "$dn" =~ .*\ VIDEO ]]
then
    fn=${dn%% VIDEO}
    if [ -z "$fn" ]
    then
        echo "WARNING! Invalid timelapse dir name; will use ./"
        OUTDIR="./"
    else
        OUTDIR="../$fn TIMELAPSE/"
        echo "Current directory name ends with VIDEO; make output in \"$OUTDIR\""
        mkdir -p "$OUTDIR"
    fi
else
    echo "Current directory name does NOT ends with VIDEO; use ./"
    OUTDIR="./"
fi


bn="$1"
bn=${bn%\.mov}
bn=${bn%\.MOV}
bn=${bn%\.mts}
bn=${bn%\.MTS}
bn=${bn%\.avi}
bn=${bn%\.AVI}
bn=${bn%\.mp4}
bn=${bn%\.MP4}
bn=${bn%\.mpg}
bn=${bn%\.MPG}
bn=${bn%\.mpeg}
bn=${bn%\.MPEG}
bn=${bn%\.flv}
bn=${bn%\.FLV}

echo "Will use base name $bn"

nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.001*PTS"       "$OUTDIR/$bn-1000x.mp4"
nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.002*PTS"       "$OUTDIR/$bn-0500x.mp4"
nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.005*PTS"       "$OUTDIR/$bn-0200x.mp4"
nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 10000k -r 60 -filter:v "setpts=0.01*PTS"        "$OUTDIR/$bn-0100x.mp4"
nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 10000k -r 60 -filter:v "setpts=0.02*PTS"        "$OUTDIR/$bn-0050x.mp4"
nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b  3000k -r 60 -filter:v "setpts=0.04*PTS"        "$OUTDIR/$bn-0025x.mp4"
nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b  3000k -r 60 -filter:v "setpts=0.066666666*PTS" "$OUTDIR/$bn-0015x.mp4"




