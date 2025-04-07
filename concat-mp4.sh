#!/bin/bash
#
# Concatenate MP4 files into a single video with no transcoding. Typical use case is to
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
        OUTDIR="./"
        OUTFILE=concat-inprogress.mp4
        FINALFILE=concat.mp4
        echo "Current directory name ends with FRAGMENTS but concat file name would be empty, Use concat.mp4"
    else
        OUTDIR="../$fn VIDEO"
        OUTFILE="../$fn VIDEO/$fn.concat-inprogress.mp4"
        FINALFILE="../$fn VIDEO/$fn.mp4"
        mkdir -p "../$fn VIDEO"
        echo "Current directory name ends with FRAGMENTS; make output \"$FINALFILE\""
    fi
else
    echo "Current directory name does NOT ends with FRAGMENTS; use concat.mp4 as output"
    OUTDIR="./"
    OUTFILE=concat-inprogress.mp4
    FINALFILE=concat.mp4
fi

if [ -e "$FINALFILE" ]
then
    echo "$FINALFILE exists; exiting."
    exit -1
fi

if [ -e "$OUTFILE" ]
then
    echo "In-progress $OUTFILE exists; remove."
    rm "$OUTFILE"
fi

if [ -e files.txt ]
then
    # Failsafe: already tried to concat?
    echo "files.txt exists; remove."
    rm files.txt
fi

echo > files.txt
for i in *.[mM][pP]4
do
    echo "file '$i'" >> files.txt
done

echo
echo
echo "============================================================================================="
echo
echo "Concatenate multiple MP4 files to $OUTFILE" / "$FINALFILE"
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

echo
echo
echo "Concat done, rename"
echo

mv "$OUTFILE" "$FINALFILE"

cd "$OUTDIR"
OFBN=$(basename "$FINALFILE")
CSF="$OFBN.sha1"
echo
echo "Calc SHA1 sum to $CSF"
sha1sum -b "./$OFBN" >> "$CSF"
echo "  Checksum calculation done"

echo "All done."
