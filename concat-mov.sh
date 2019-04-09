#!/bin/bash
#
# Concatenate MOV files into a single video with no transcoding. Typical use case is to
# merge fragments of video created by cheap action cameras.
#
# See
# http://stackoverflow.com/questions/11779490/ffmpeg-how-to-add-new-audio-not-mixing-in-video
# http://stackoverflow.com/questions/12938581/ffmpeg-mux-video-and-audio-from-another-video-mapping-issue/12943003#12943003
# https://trac.ffmpeg.org/wiki/How%20to%20speed%20up%20/%20slow%20down%20a%20video
# https://trac.ffmpeg.org/wiki/Concatenate


# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found"; exit 1; }



# Determine target file
# see https://stackoverflow.com/a/1371283
# see https://stackoverflow.com/a/2172365
dn=${PWD##*/}

if [[ "$dn" =~ .*\ FRAGMENTS ]]
then
    fn=${dn%% FRAGMENTS}
    if [ -z "$fn" ]
    then
        echo "WARNING! Invalid concat file name; will use concat.MOV"
        OUTFILE=concat.MOV
    else
        OUTFILE="../$fn.MOV"
        echo "Current directory name ends with FRAGMENTS; make output \"$OUTFILE\""
    fi
else
    echo "Current directory name does NOT ends with FRAGMENTS; use concat.MOV as output"
    OUTFILE=concat.MOV
fi

if [ -e "$OUTFILE" ]
then
    echo "$OUTFILE exists; exiting."
    exit -1
fi

if [ -e files.txt ]
then
    # Failsafe: already tried to concat?
    echo "files.txt exists; exiting."
   exit -1
fi

echo > files.txt
for i in *.MOV
do
    echo "file '$i'" >> files.txt
done

echo
echo
echo "============================================================================================="
echo
echo "Concatenate multiple MOV files to $OUTFILE"
echo
echo "============================================================================================="
echo
echo
echo "Input files:"
echo
cat files.txt | sed 's/^/    /'
echo
echo

nice -19 ffmpeg -f concat -i files.txt -c copy "$OUTFILE"

