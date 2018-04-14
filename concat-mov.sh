#!/bin/bash
# http://stackoverflow.com/questions/11779490/ffmpeg-how-to-add-new-audio-not-mixing-in-video
# http://stackoverflow.com/questions/12938581/ffmpeg-mux-video-and-audio-from-another-video-mapping-issue/12943003#12943003
# https://trac.ffmpeg.org/wiki/How%20to%20speed%20up%20/%20slow%20down%20a%20video
# https://trac.ffmpeg.org/wiki/Concatenate

if [ -e concat.MOV ]
then
    echo "concat.MOV exists; exiting."
    exit -1
fi

echo > files.txt
for i in *.MOV
do
    echo "file '$i'" >> files.txt
done

echo "Concat the following files into concat.MOV:"
echo
cat files.txt
echo
echo

nice -19 ffmpeg -f concat -i files.txt -c copy "concat.MOV"

