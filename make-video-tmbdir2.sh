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
    echo "    -h          Print help and exit"
    echo "    -preview    Use fast and reduced preview"
    echo "    -crf18      Use crf18"
    echo "    -force1080p Scale output to based on 1920 x 1080 resolution"
    echo "    -crf24      Use crf24"
    echo "    -crf28      Use crf28"
    echo "    -crf30      Use crf30"
    echo "    -crf32      Use crf32"
    echo
}


# Launch transcoding
#
# $1 inifle to read
# $2 opts
# $3 extopts
# $4 target dir
# $5 target file

function transcode() {
        echo
        echo
        echo
        echo "+------------------------------------------------------------------------------------------------------------"
        echo "| Launch ffmpeg"
        echo "|"
        echo "|       input file:  \"$1\""
        echo "|       opts:        \"$2\""
        echo "|       extopts:     \"$3\""
        echo "|       target dir:  \"$4\""
        echo "|       target file: \"$5\""
        echo "+------------------------------------------------------------------------------------------------------------"
        echo
        echo
        echo


        mkdir -p "$4"
        if [ -f "$4/$5" ] ; then
            echo "Target file $4/$5 exists."
        else
            # see http://mywiki.wooledge.org/BashFAQ/089
            nice -19 ffmpeg -i "$1" $2 $3 "$4/$5" </dev/null
        fi
}

# Collect cli options ================================================================================

if [ $# == 0 ] ; then usage ; exit 1 ; fi

ENABLECRF18=false
ENABLECRF24=false
ENABLECRF28=false
ENABLECRF30=false
ENABLECRF32=false
ENABLEPREVIEW=false
FORCE1080P=false


while [ $# -gt 0 ] ; do
    case "$1" in
        -h )          usage ; exit ;; 
        -preview )    ENABLEPREVIEW=true ; shift ;;
        -force1080p ) FORCE1080P=true ; shift ;;
        -crf18 )      ENABLECRF18=true ; shift ;;
        -crf24 )      ENABLECRF24=true ; shift ;;
        -crf28 )      ENABLECRF28=true ; shift ;;
        -crf30 )      ENABLECRF30=true ; shift ;;
        -crf32 )      ENABLECRF32=true ; shift ;;
        * )           echo "Unknown option $1" ; exit 1 ;;
    esac
done





# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffprobe >/dev/null 2>&1 || { echo >&2 "ffprobe not found"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found"; exit 1; }


PWD=$(pwd)

# Use CRF, see https://trac.ffmpeg.org/wiki/Encode/H.264

TDIRPREFIX="../"$(basename "${PWD}")

find -wholename "*.MTS" -or -wholename "*.mov" -or -wholename "*.MOV" -or -wholename "*.mp4" -or -wholename "*.MP4" -or -wholename "*.avi" -or -wholename "*.wmv" -or -wholename "*.mpg"  | while read infile
do
    dir=$(dirname "$infile")
    fil=$(basename "$infile" .MTS)
    fil=$(basename "$fil" .MOV)
    fil=$(basename "$fil" .mov)
    fil=$(basename "$fil" .mp4)
    fil=$(basename "$fil" .MP4)
    fil=$(basename "$fil" .avi)
    fil=$(basename "$fil" .wmv)
    fil=$(basename "$fil" .mpg)

    
    if [[ "$dir" =~ .*\ FRAGMENTS ]] ; then
        echo "File \"$infile\" in FRAGMENTS directory is skipped: \"$dir\""
        continue
    fi

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

    # sometimes stream 1 is the video stream
    # workaround for a few combinations implemented
    # for proeper fix see https://stackoverflow.com/questions/41115917/ffprobe-select-audio-and-video-streams

    
    streams_stream_0_codec_long_name=""
    streams_stream_0_width=""
    streams_stream_0_height=""
    streams_stream_0_r_frame_rate=""
    streams_stream_1_width=""
    streams_stream_1_height=""
    streams_stream_1_r_frame_rate=""

    streams_stream_1_codec_long_name=""
    streams_stream_1_sample_rate=""
    
    eval "$probe"

    

    if [ "${streams_stream_0_width}" == "3840" ] && [ "${streams_stream_0_height}" == "2160" ] 
    then
        scalepreview="-s 640x360"
        aspect="-aspect 16:9"
        scale="-s 3840x2160" # usually redundant but consider rotate+crop
    elif [ "${FORCE1080P}" =  true ] 
    then
        scalepreview="-s 640x360"
        aspect="-aspect 16:9"
        scale="-s 1920x1080" # usually redundant but consider rotate+crop
    elif [ "${streams_stream_0_width}" == "1920" ] && [ "${streams_stream_0_height}" == "1080" ] 
    then
        scalepreview="-s 640x360"
        aspect="-aspect 16:9"
        scale="-s 1920x1080" # usually redundant but consider rotate+crop

    elif [ "${streams_stream_0_width}" == "1280" ] && [ "${streams_stream_0_height}" == "720" ]         
    then

        scalepreview="-s 640x360"
        aspect="-aspect 16:9"
        scale="-s 1280x720" # usually redundant but consider rotate+crop

    elif [ "${streams_stream_1_width}" == "1280" ] && [ "${streams_stream_1_height}" == "720" ]         
    then

        scalepreview="-s 640x360"
        aspect="-aspect 16:9"
        scale="-s 1280x720" # usually redundant but consider rotate+crop

    else
        echo "UNKNOWN RESOULUTION ${streams_stream_0_width} x ${streams_stream_0_height}"
        exit
    fi
        

    if [ "${streams_stream_1_r_frame_rate}" == "24000/1001" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "30000/1001" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "30/1" ]
    then
        rate=""
    elif [ "${streams_stream_1_r_frame_rate}" == "30/1" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "25/1" ]
    then
        rate=""
    elif [ "${streams_stream_1_r_frame_rate}" == "24/1" ]
    then
        rate=""
    elif [ "${streams_stream_0_r_frame_rate}" == "50/1" ]
    then
        rate="-r 25"
    elif [ "${streams_stream_0_r_frame_rate}" == "60/1" ]
    then
        rate="-r 30"
    elif [ "${streams_stream_1_r_frame_rate}" == "60/1" ]
    then
        rate="-r 30"
    elif [ "${streams_stream_0_r_frame_rate}" == "240/1" ]
    then
        rate="-r 30"
    else
        echo "UNKNOWN FRAMERATE: ${streams_stream_0_r_frame_rate}"
        exit
    fi


    echo "Video specific settings:"
    echo
    echo "    Scale:                  \"$scale\""
    echo "    Scaling in preview:     \"$scalepreview\""
    echo "    Aspect:                 \"$aspect\""
    echo "    Framerate:              \"$rate\""
    echo
    echo "    Target directory base:  \"${TDIRPREFIX}\""
    echo
    echo "    Additional options:     \"${EXTOPTS}\""
    



    # Launch transcodes ================================================================================================================


    if [ "$ENABLEPREVIEW" = true ] ; then
        # $1 inifle to read
        # $2 opts
        # $3 extopts
        # $4 target dir
        # $5 target file
        transcode \
            "$infile" \
            "-vcodec libx264 ${rate} ${aspect} ${scalepreview}  -preset fast -f mp4 -g 50 -movflags +faststart -crf 32 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 96k" \
            "$EXTOPTS" \
            "${TDIRPREFIX}-preview/${dir}" \
            "${fil}.mp4"
    fi

    if [ "$ENABLECRF32" = true ] ; then
        # $1 inifle to read
        # $2 opts
        # $3 extopts
        # $4 target dir
        # $5 target file
        transcode \
            "$infile" \
            "-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -g 50 -movflags +faststart -crf 32 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k" \
            "$EXTOPTS" \
            "${TDIRPREFIX}-h264-crf32-a192/${dir}" \
            "${fil}.mp4"

    fi

    if [ "$ENABLECRF30" = true ] ; then
        transcode \
            "$infile" \
            "-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -g 50 -movflags +faststart -crf 30 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k" \
            "$EXTOPTS" \
            "${TDIRPREFIX}-h264-crf30-a192/${dir}" \
            "${fil}.mp4"

    fi

    if [ "$ENABLECRF28" = true ] ; then
        transcode \
            "$infile" \
            "-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -g 50 -movflags +faststart -crf 28 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k" \
            "$EXTOPTS" \
            "${TDIRPREFIX}-h264-crf28-a192/${dir}" \
            "${fil}.mp4"

    fi

    if [ "$ENABLECRF24" = true ] ; then
        transcode \
            "$infile" \
            "-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -g 50 -movflags +faststart -crf 24 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k" \
            "$EXTOPTS" \
            "${TDIRPREFIX}-h264-crf24-a192/${dir}" \
            "${fil}.mp4"

    fi

    if [ "$ENABLECRF18" = true ] ; then
        transcode \
            "$infile" \
            "-vcodec libx264 ${rate} ${aspect} -preset slow -f mp4 -g 50 -movflags +faststart -crf 18 -acodec aac -strict experimental -ac 2 -ar 44100 -ab 192k" \
            "$EXTOPTS" \
            "${TDIRPREFIX}-h264-crf18-a192/${dir}" \
            "${fil}.mp4"

    fi


       
    
    
    # OPTSFHL="-vcodec libx264 ${rate} ${scalefhd} ${aspect} -b 1000k -acodec libmp3lame -ac 2 -ar 44100 -ab 128k"
    # OPTSFH="-vcodec libx264 ${rate} ${scalefhd} ${aspect} -b 1500k -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSHI="-vcodec libx264 ${rate} ${scalehi} ${aspect} -b 1500k -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSLO="-vcodec flv -f flv ${rate} ${scalelo} ${aspect} -b 300k -g 160 -cmp 2 -subcmp 2 -mbd 2 -trellis 2 -acodec libmp3lame -ac 2 -ar 22050 -ab 64k"


    # Use mp4/aac to be HTML5 video compatible
    # OPTSCRF18="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 18 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF24="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 24 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF28="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 28 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF30="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 30 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"
    # OPTSCRF32="-vcodec libx264 ${rate} ${aspect} -preset slow -crf 32 -acodec libmp3lame -ac 2 -ar 44100 -ab 192k"

    # See https://gist.github.com/yellowled/1439610

    
    # see http://stackoverflow.com/questions/2953646/how-to-declare-and-use-boolean-variables-in-shell-script

done    


echo
echo
echo
echo 
echo "+------------------------------------------------------------------------------------------------------------"
echo "|"
echo "| All video processing is done."
echo "|"
echo "+------------------------------------------------------------------------------------------------------------"
echo
echo
echo
echo 
