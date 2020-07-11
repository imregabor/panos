#!/bin/bash

set -e
set -o pipefail
set -u

function usage() {
    echo "Usage:"
    echo
    echo "  $0 [OPTIONS]"
    echo
    echo "  Options:"
    echo
    echo "    -h     Print help and exit"
    echo "    -crf18 Use crf18"
    echo "    -crf24 Use crf24"
    echo "    -crf28 Use crf28"
    echo "    -crf30 Use crf30"
    echo "    -crf32 Use crf32"
    echo "    -hi    Use hi"
    echo "    -lo    Use lo"
    echo "    -fh    Use fh"
    echo
}

if [ $# == 0 ] ; then usage ; exit 1 ; fi

#ENABLEHI=true
#ENABLELO=true
#ENABLEFH=true
#ENABLECRF18=true
#ENABLECRF24=true

ENABLEHI=false
ENABLELO=false
ENABLEFH=false
ENABLECRF18=false
ENABLECRF24=false
ENABLECRF28=false
ENABLECRF30=false
ENABLECRF32=false


while [ $# -gt 0 ] ; do
    case "$1" in
        -h )     usage ; exit ;; 
        -crf18 ) ENABLECRF18=true ; shift ;;
        -crf24 ) ENABLECRF24=true ; shift ;;
        -crf28 ) ENABLECRF28=true ; shift ;;
        -crf30 ) ENABLECRF30=true ; shift ;;
        -crf32 ) ENABLECRF32=true ; shift ;;
        -hi )    ENABLEHI=true ; shift ;;
        -lo )    ENABLELO=true ; shift ;;
        -fh )    ENABLEFH=true ; shift ;;
        * )      echo "Unknown option $1" ; exit 1 ;;
    esac
done





# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffprobe >/dev/null 2>&1 || { echo >&2 "ffprobe not found"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found"; exit 1; }


PWD=$(pwd)

TDIRFHL="../"$(basename "${PWD}")"-fhd-avi-h264-v1000-a128/"
TDIRFH="../"$(basename "${PWD}")"-fhd-avi-h264-v1500-a192/"
TDIRHI="../"$(basename "${PWD}")"-avi-h264-v1500-a192/"
TDIRLO="../"$(basename "${PWD}")"-flv-v300-a64/"

# Use CRF, see https://trac.ffmpeg.org/wiki/Encode/H.264
TDIRCRF18="../"$(basename "${PWD}")"-h264-crf18-a192"
TDIRCRF24="../"$(basename "${PWD}")"-h264-crf24-a192"
TDIRCRF28="../"$(basename "${PWD}")"-h264-crf28-a192"
TDIRCRF30="../"$(basename "${PWD}")"-h264-crf30-a192"
TDIRCRF32="../"$(basename "${PWD}")"-h264-crf32-a192"


find -wholename "*.MTS" -or -wholename "*.mov" -or -wholename "*.MOV" -or -wholename "*.mp4" -or -wholename "*.MP4" -or -wholename "*.avi" | while read infile
do
    dir=$(dirname "$infile")
    fil=$(basename "$infile" .MTS)
    fil=$(basename "$fil" .MOV)
    fil=$(basename "$fil" .mov)
    fil=$(basename "$fil" .mp4)
    fil=$(basename "$fil" .MP4)
    fil=$(basename "$fil" .avi)

    
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
    
    # External options
    EXTOPTS=""
    if [ -e "$infile.ffmpegopts" ]
    then
        EXTOPTS=`cat "$infile.ffmpegopts" | head -1 | tr -d '\r'`
        echo
        echo "Using additional ffmpeg options \"$EXTOPTS\""
        echo
    fi


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
    

    if [ "${streams_stream_0_width}" == "3840" ] && [ "${streams_stream_0_height}" == "2160" ] 
    then
        scalehi="-s 1280x720"
        scalelo="-s 640x360"
        aspect="-aspect 16:9"
        dofhd="true"
        scalefhd="-s 3840x2160" # usually redundant but consider rotate+crop

    
    elif [ "${streams_stream_0_width}" == "1920" ] && [ "${streams_stream_0_height}" == "1080" ] 
    then
        scalehi="-s 1280x720"
        scalelo="-s 640x360"
        aspect="-aspect 16:9"
        dofhd="true"
        scalefhd="-s 1920x1080" # usually redundant but consider rotate+crop

    elif [ "${streams_stream_0_width}" == "1280" ] && [ "${streams_stream_0_height}" == "720" ]         
    then
        scalehi="-s 1280x720" # usually redundant but consider rotate+crop
        scalelo="-s 640x360"
        aspect="-aspect 16:9"
        scalefhd=""
        dofhd=""
    else
        echo "UNKNOWN RESOULUTION ${streams_stream_0_width} x ${streams_stream_0_height}"
        exit
    fi
        
    if [ "${streams_stream_0_r_frame_rate}" == "30000/1001" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "30/1" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "25/1" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "50/1" ]
    then
        rate="-r 25"
    elif [ "${streams_stream_0_r_frame_rate}" == "60/1" ]
    then
        rate="-r 30"
    else
        echo "UNKNOWN FRAMERATE: ${streams_stream_0_r_frame_rate}"
        exit
    fi
       
    
    TDH="${TDIRHI}/${dir}"
    TDL="${TDIRLO}/${dir}"
    TDF="${TDIRFH}/${dir}"
    TDFHL="${TDIRFHL}/${dir}"
    TDCRF18="${TDIRCRF18}/${dir}"
    TDCRF24="${TDIRCRF24}/${dir}"
    TDCRF28="${TDIRCRF28}/${dir}"
    TDCRF30="${TDIRCRF30}/${dir}"
    TDCRF32="${TDIRCRF32}/${dir}"

    TFL="${TDL}/${fil}.flv"
    TFH="${TDH}/${fil}.avi"
    TFF="${TDF}/${fil}.avi"
    TFFHL="${TDFHL}/${fil}.avi"
#    TFCRF18="${TDCRF18}/${fil}.avi"
#    TFCRF24="${TDCRF24}/${fil}.avi"
#    TFCRF28="${TDCRF28}/${fil}.avi"
#    TFCRF30="${TDCRF30}/${fil}.avi"
#    TFCRF32="${TDCRF32}/${fil}.avi"
    TFCRF18="${TDCRF18}/${fil}.mp4"
    TFCRF24="${TDCRF24}/${fil}.mp4"
    TFCRF28="${TDCRF28}/${fil}.mp4"
    TFCRF30="${TDCRF30}/${fil}.mp4"
    TFCRF32="${TDCRF32}/${fil}.mp4"
    
    OPTSFHL="-vcodec libx264 ${rate} ${scalefhd} ${aspect} -b 1000k -acodec libmp3lame -ac 2 -ar 44100 -ab 128k"
    OPTSFH="-vcodec libx264 ${rate} ${scalefhd} ${aspect} -b 1500k -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    OPTSHI="-vcodec libx264 ${rate} ${scalehi} ${aspect} -b 1500k -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    OPTSLO="-vcodec flv -f flv ${rate} ${scalelo} ${aspect} -b 300k -g 160 -cmp 2 -subcmp 2 -mbd 2 -trellis 2 -acodec libmp3lame -ac 2 -ar 22050 -ab 64k"


    # Use mp4/aac to be HTML5 video compatible
    # OPTSCRF18="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 18 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF24="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 24 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF28="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 28 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF30="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 30 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF32="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 32 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"

    # See https://gist.github.com/yellowled/1439610

    OPTSCRF18="-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -crf 18 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k"
    OPTSCRF24="-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -crf 24 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k"
    OPTSCRF28="-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -crf 28 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k"
    OPTSCRF30="-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -crf 30 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k"
    OPTSCRF32="-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -crf 32 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k"

    echo "Video specific settings:"
    echo
    echo "    dofhd:                  \"$dofhd\""
    echo 
    echo "    Scaling in fhd:         \"$scalefhd\""
    echo "    Scaling in high:        \"$scalehi\""
    echo "    Scaling in low:         \"$scalelo\""
    echo "    Aspect:                 \"$aspect\""
    echo "    Framerate:              \"$rate\""
    echo
    echo "    Target directory crf18: \"${TDCRF18}\""
    echo "    Target directory fhd:   \"${TDF}\""
    echo "    Target directory hi:    \"${TDH}\""
    echo "    Target directory lo:    \"${TDL}\""
    echo "    Target file crf18:      \"${TFCRF18}\""
    echo "    Target file crf24:      \"${TFCRF24}\""
    echo "    Target file crf28:      \"${TFCRF28}\""
    echo "    Target file crf30:      \"${TFCRF32}\""
    echo "    Target file crf32:      \"${TFCRF30}\""
    echo "    Target file fhd:        \"${TFF}\""
    echo "    Target file hi:         \"${TFH}\""
    echo "    Target file lo:         \"${TFL}\""
    echo
    echo "    Full options line fhd:  \"${OPTSFH}\""
    echo "    Full options line hi:   \"${OPTSHI}\""
    echo "    Full options line lo:   \"${OPTSLO}\""
    echo
    echo "    Additional options:     \"${EXTOPTS}\""
    
    
    # see http://stackoverflow.com/questions/2953646/how-to-declare-and-use-boolean-variables-in-shell-script

    if [ "$ENABLECRF32" = true ] && [ ! -e "$TFCRF32" ]
    then
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg on CRF-32"
        echo "|"
        echo "|       input file:  \"$infile\""
        echo "|       output file: \"$TFCRF32\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo
        mkdir -p "${TDCRF32}"
        # see http://mywiki.wooledge.org/BashFAQ/089
        nice -19 ffmpeg -i "$infile" $OPTSCRF32 $EXTOPTS "$TFCRF32" </dev/null
    else
        echo "$TFCRF32 exists or not requested."
    fi


    if [ "$ENABLECRF30" = true ] && [ ! -e "$TFCRF30" ]
    then
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg on CRF-30"
        echo "|"
        echo "|       input file:  \"$infile\""
        echo "|       output file: \"$TFCRF30\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo
        mkdir -p "${TDCRF30}"
        # see http://mywiki.wooledge.org/BashFAQ/089
        nice -19 ffmpeg -i "$infile" $OPTSCRF30 $EXTOPTS "$TFCRF30" </dev/null
    else
        echo "$TFCRF30 exists or not requested."
    fi

    if [ "$ENABLECRF28" = true ] && [ ! -e "$TFCRF28" ]
    then
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg on CRF-28"
        echo "|"
        echo "|       input file:  \"$infile\""
        echo "|       output file: \"$TFCRF28\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo
        mkdir -p "${TDCRF28}"
        # see http://mywiki.wooledge.org/BashFAQ/089
        nice -19 ffmpeg -i "$infile" $OPTSCRF28 $EXTOPTS "$TFCRF28" </dev/null
    else
        echo "$TFCRF28 exists or not requested."
    fi


    if [ "$ENABLECRF24" = true ] && [ ! -e "$TFCRF24" ]
    then
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg on CRF-24"
        echo "|"
        echo "|       input file:  \"$infile\""
        echo "|       output file: \"$TFCRF24\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo
        mkdir -p "${TDCRF24}"
        # see http://mywiki.wooledge.org/BashFAQ/089
        nice -19 ffmpeg -i "$infile" $OPTSCRF24 $EXTOPTS "$TFCRF24" </dev/null
    else
        echo "$TFCRF24 exists or not requested."
    fi



    if [ "$ENABLECRF18" = true ] && [ ! -e "$TFCRF18" ]
    then
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg on CRF-18"
        echo "|"
        echo "|       input file:  \"$infile\""
        echo "|       output file: \"$TFCRF18\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo
        mkdir -p "${TDCRF18}"
        # see http://mywiki.wooledge.org/BashFAQ/089
        nice -19 ffmpeg -i "$infile" $OPTSCRF18 $EXTOPTS "$TFCRF18" </dev/null
    else
        echo "$TFCRF18 exists or not requested."
    fi



    if [ "$ENABLELO" = true ] && [ ! -e "$TFL" ]
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
        nice -19 ffmpeg -i "$infile" $OPTSLO $EXTOPTS "$TFL" </dev/null
    else
        echo "$TFL exists or not requested."
    fi

    
    
    if [ "$ENABLEHI" = true ] && [ ! -e "$TFH" ]
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
        nice -19 ffmpeg -i "$infile" $OPTSHI $EXTOPTS "$TFH" </dev/null
    else
        echo "$TFH exists or not requested."
    fi


    if [ "$ENABLEFH" = true ] && [ ! -z "$dofhd" ] 
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
            nice -19 ffmpeg -i "$infile" $OPTSFH $EXTOPTS "$TFF" </dev/null
        else
            echo "$TFF exists or not requested."
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
            nice -19 ffmpeg -i "$infile" $OPTSFHL $EXTOPTS "$TFFHL" </dev/null
        else
            echo "$TFFHL exists or not requested."
        fi

    fi

done    
