#!/bin/bash

set -e
set -o pipefail
set -u 

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffprobe >/dev/null 2>&1 || { echo >&2 "ffprobe not found"; exit 1; }

find -wholename "*.MTS" -or -wholename "*.MOV" -or -wholename "*.MP4" -or -wholename "*.mp4" -or -wholename "*.avi" | while read infile
do
    
    
    echo
    echo "Probe input file: \"$infile\""
    echo
    
    if [ ! -e "${infile}.info.json" ]
    then
        echo "    Launch ffprobe on file - json output"
        
        ffprobe -of json -v quiet -show_format -show_streams -show_programs -show_chapters  -i "$infile" < /dev/null > "${infile}.info.json" 
    else
        echo "    Output file already exists."
    fi

    if [ ! -e "${infile}.info.txt" ]
    then
        echo "    Launch ffprobe on file - flat text output"

        ffprobe -of flat=s=_ -v quiet -show_format -show_streams -show_programs -show_chapters  -i "$infile" < /dev/null > "${infile}.info.txt" 
    else
        echo "    Output file already exists."
    fi
done    

echo
echo "----------------------------------------------------------------------"
echo "All done."
echo "----------------------------------------------------------------------"
