#!/bin/bash

set -e

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffprobe >/dev/null 2>&1 || { echo >&2 "ffprobe not found"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found"; exit 1; }


PWD=$(pwd)

TDIRFHL="../"$(basename "${PWD}")"-fhd-avi-h264-v1000-a128/"
TDIRFH="../"$(basename "${PWD}")"-fhd-avi-h264-v1500-a192/"
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

    dofhd=""
    
    if [ "${streams_stream_0_width}" == "1920" ] && [ "${streams_stream_0_height}" == "1080" ] 
    then
        scalehi="-s 1280x720"
        scalelo="-s 640x360"
        aspect="-aspect 16:9"
        dofhd="true"
        scalefhd=""

    elif [ "${streams_stream_0_width}" == "1280" ] && [ "${streams_stream_0_height}" == "720" ]         
    then
        scalehi=""
        scalelo="-s 640x360"
        aspect="-aspect 16:9"
        scalefhd=""
        dofhd=""
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
    TDF="${TDIRFH}/${dir}"
    TDFHL="${TDIRFHL}/${dir}"
    TFL="${TDL}/${fil}.flv"
    TFH="${TDH}/${fil}.avi"
    TFF="${TDF}/${fil}.avi"
    TFFHL="${TDFHL}/${fil}.avi"
    
    OPTSFHL="-vcodec libx264 ${rate} ${scalefhd} ${aspect} -b 1000k -acodec libmp3lame -ac 2 -ar 44100 -ab 128k"
    OPTSFH="-vcodec libx264 ${rate} ${scalefhd} ${aspect} -b 1500k -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    OPTSHI="-vcodec libx264 ${rate} ${scalehi} ${aspect} -b 1500k -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    OPTSLO="-vcodec flv -f flv ${rate} ${scalelo} ${aspect} -b 300k -g 160 -cmp 2 -subcmp 2 -mbd 2 -trellis 2 -acodec libmp3lame -ac 2 -ar 22050 -ab 64k"

    echo "Video specific settings:"
    echo
    echo "    dofhd:                 \"$dofhd\""
    echo 
    echo "    Scaling in fhd:        \"$scalefhd\""
    echo "    Scaling in high:       \"$scalehi\""
    echo "    Scaling in low:        \"$scalelo\""
    echo "    Aspect:                \"$aspect\""
    echo "    Framerate:             \"$rate\""
    echo
    echo "    Target directory fhd:  \"${TDF}\""
    echo "    Target directory hi:   \"${TDH}\""
    echo "    Target directory lo:   \"${TDL}\""
    echo "    Target file fhd:       \"${TFF}\""
    echo "    Target file hi:        \"${TFH}\""
    echo "    Target file lo:        \"${TFL}\""
    echo
    echo "    Full options line fhd: \"${OPTSFH}\""
    echo "    Full options line hi:  \"${OPTSHI}\""
    echo "    Full options line lo:  \"${OPTSLO}\""
    
    



    if [ ! -e "$TFL" ]
    then
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg on lo"
        echo "|"
        echo "|       input file:  \"$infile\""
        echo "|       output file: \"$TFL\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo
        mkdir -p "${TDL}"
        # see http://mywiki.wooledge.org/BashFAQ/089
        ffmpeg -i "$infile" $OPTSLO "$TFL" </dev/null
    else
        echo "$TFL exists."
    fi
    
    
    if [ ! -e "$TFH" ]
    then
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg on hi"
        echo "|"
        echo "|       input file:  \"$infile\""
        echo "|       output file: \"$TFH\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo
        mkdir -p "${TDH}"
        ffmpeg -i "$infile" $OPTSHI "$TFH" </dev/null
    else
        echo "$TFH exists"
    fi


    if [ ! -z "$dofhd" ] 
    then
        # FHD run
        if [ ! -e "$TFF" ]
        then
            echo
            echo
            echo
            echo "+------------------------------------------------------------------------------------------------------------"
            echo "| Launch ffmpeg on fhd"
            echo "|"
            echo "|       input file:  \"$infile\""
            echo "|       output file: \"$TFF\""
            echo "+------------------------------------------------------------------------------------------------------------"
            echo
            echo
            echo
            mkdir -p "${TDF}"
            # see http://mywiki.wooledge.org/BashFAQ/089
            ffmpeg -i "$infile" $OPTSFH "$TFF" </dev/null
        else
            echo "$TFF exists."
        fi


        if [ ! -e "$TFFHL" ]
        then
            echo
            echo
            echo
            echo "+------------------------------------------------------------------------------------------------------------"
            echo "| Launch ffmpeg on fhd - lower bitrate"
            echo "|"
            echo "|       input file:  \"$infile\""
            echo "|       output file: \"$TFFHL\""
            echo "+------------------------------------------------------------------------------------------------------------"
            echo
            echo
            echo
            mkdir -p "${TDFHL}"
            # see http://mywiki.wooledge.org/BashFAQ/089
            ffmpeg -i "$infile" $OPTSFHL "$TFFHL" </dev/null
        else
            echo "$TFFHL exists."
        fi

    fi

done    
