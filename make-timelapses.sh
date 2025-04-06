#!/bin/bash

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found"; exit 1; }



if [ -z "$1" ]; then
    echo "Input file name missing. Exiting."
    exit -1
fi

if [ ! -f "$1" ]; then
    echo "Input file \"$1\" not found. Exiting."
    exit -1
fi

INFILE=$1



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

echo
echo
echo "========================================================================================"
echo
echo "Generate timelapses"
echo
echo "  Input file:       $INFILE"
echo "  Output directory: $OUTDIR"
echo "  Base name:        $bn"
echo
echo "========================================================================================"
echo
echo
echo
echo

echo "Will use base name $bn"


function run {
  BITRATE=$1
  PTSM=$2
  SPEED=$3

  OUTFILE="$OUTDIR/$bn-${SPEED}x.mp4"
  OUTFILE_INPROGRESS="$OUTDIR/$bn-${SPEED}x.inprogress.mp4"
  if [ -f "$OUTFILE" ] ; then
    echo "Output file $OUTFILE exists, skip."
    return
  fi

  if [ -f "$OUFILE_INPROGRESS" ]; then
    echo "Temp out file $OUTFILE_INPROGRESS exists, delete"
    rm "$OUFILE_INPROGRESS"
  fi


  echo
  echo
  echo "================================================="
  echo
  echo "  Start $SPEED x"
  echo
  echo "================================================="
  echo
  echo


  nice -19 ffmpeg -i "$INFILE" -an -vcodec libx264 -b "$BITRATE" -r 60 -filter:v "setpts=$PTSM*PTS" "$OUTFILE_INPROGRESS"
  mv "$OUTFILE_INPROGRESS" "$OUTFILE"

  echo "Done."
  echo
  echo

}


run 15000k 0.001 1000
run 15000k 0.002 0500
run 15000k 0.005 0200
run 10000k 0.01  0100
run 10000k 0.02  0050
run  3000k 0.04  0025
run  3000k 0.066666666 0015

# nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.001*PTS"       "$OUTDIR/$bn-1000x.mp4"
# nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.002*PTS"       "$OUTDIR/$bn-0500x.mp4"
# nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.005*PTS"       "$OUTDIR/$bn-0200x.mp4"
# nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 10000k -r 60 -filter:v "setpts=0.01*PTS"        "$OUTDIR/$bn-0100x.mp4"
# nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b 10000k -r 60 -filter:v "setpts=0.02*PTS"        "$OUTDIR/$bn-0050x.mp4"
# nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b  3000k -r 60 -filter:v "setpts=0.04*PTS"        "$OUTDIR/$bn-0025x.mp4"
# nice -19 ffmpeg -i "$1" -an -vcodec libx264 -b  3000k -r 60 -filter:v "setpts=0.066666666*PTS" "$OUTDIR/$bn-0015x.mp4"




