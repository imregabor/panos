#!/bin/bash

PWD=$(pwd)
TDIRHI="../"$(basename "${PWD}")"-avi-h264-v1500-a192/"
TDIRLO="../"$(basename "${PWD}")"-flv-v300-a64/"


find -wholename "*.MTS" -or -wholename "*.MOV" | while read infile
do
    dir=$(dirname "$infile")
    fil=$(basename "$infile" .MTS)
    fil=$(basename "$fil" .MOV)
    
    echo 
    echo
    echo
    echo "+------------------------------------------------------------------------------------------------------------"
    echo "|"
    echo "| Processing input file: \"$infile\""
    echo "|"
    echo "| dir:  \"$dir\""
    echo "| fil:  \"$fil\""
    echo "|"
    echo "+------------------------------------------------------------------------------------------------------------"
    
    echo
    echo "Launch ffprobe on file"
    echo
    probe=`ffprobe -v error -of flat=s=_ -show_entries stream=width,height,r_frame_rate,codec_long_name,duration,sample_rate,codec_name -i "$infile" | dos2unix`
    
    
    echo -e "$probe" | sed "s/^/    /"
    echo
    echo
    
    streams_stream_0_codec_long_name=""
    streams_stream_0_width=""
    streams_stream_0_height=""
    streams_stream_0_r_frame_rate=""
    streams_stream_1_codec_long_name=""
    streams_stream_1_sample_rate=""
    
    eval "$probe"

    
    if [ "${streams_stream_0_width}" == "1920" ] && [ "${streams_stream_0_height}" == "1080" ] 
    then
        scalehi="-s 1280x720"
        scalelo="-s 640x360"
        aspect="-aspect 16:9"
    elif [ "${streams_stream_0_width}" == "1280" ] && [ "${streams_stream_0_height}" == "720" ]         
    then
        scalehi=""
        scalelo="-s 640x360"
        aspect="-aspect 16:9"
    else
        echo "UNKNOWN RESOULUTION"
        exit
    fi
        
    if [ "${streams_stream_0_r_frame_rate}" == "30000/1001" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "50/1" ]
    then
        rate="-r 25"
    else
        echo "UNKNOWN FRAMERATE"
    fi
       
    
    TDH="${TDIRHI}/${dir}"
    TDL="${TDIRLO}/${dir}"
    TFL="${TDL}/${fil}.flv"
    TFH="${TDH}/${fil}.avi"
    
    OPTSHI="-vcodec libx264 ${rate} ${scalehi} ${aspect} -b 1500k -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    OPTSLO="-vcodec flv -f flv ${rate} ${scalelo} ${aspect} -b 300k -g 160 -cmp 2 -subcmp 2 -mbd 2 -trellis 2 -acodec libmp3lame -ac 2 -ar 22050 -ab 64k"

    echo "Video specific settings:"
    echo 
    echo "    Scaling in high:      \"$scalehi\""
    echo "    Scaling in low:       \"$scalelo\""
    echo "    Aspect:               \"$aspect\""
    echo "    Framerate:            \"$rate\""
    echo
    echo "    Target directory hi:  \"${TDH}\""
    echo "    Target directory lo:  \"${TDL}\""
    echo "    Target file hi:       \"${TFH}\""
    echo "    Target file lo:       \"${TFL}\""
    echo
    echo "    Full options line hi: \"${OPTSHI}\""
    echo "    Full options line lo: \"${OPTSLO}\""
    
    
    mkdir -p "${TDH}"
    mkdir -p "${TDL}"
    
    echo
    echo
    echo
    echo "+------------------------------------------------------------------------------------------------------------"
    echo "| Launch ffmpeg on lo"
    echo "+------------------------------------------------------------------------------------------------------------"
    echo
    echo
    echo
    if [ ! -e "$TFL" ]
    then
        ffmpeg -i "$infile" $OPTSLO "$TFL"
    fi
    
    echo
    echo
    echo
    echo "+------------------------------------------------------------------------------------------------------------"
    echo "| Launch ffmpeg on hi"
    echo "+------------------------------------------------------------------------------------------------------------"
    echo
    echo
    echo
    
    if [ ! -e "$TFH" ]
    then
        ffmpeg -i "$infile" $OPTSHI "$TFH"
    fi
done    
