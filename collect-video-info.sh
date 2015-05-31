#!/bin/bash

find -wholename "*.MTS" -or -wholename "*.MOV" | while read infile
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
