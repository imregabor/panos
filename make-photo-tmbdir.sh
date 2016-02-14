#!/bin/bash

set -e

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v convert >/dev/null 2>&1 || { echo >&2 "convert not found"; exit 1; }



PWD=`pwd`
SIZE=800
if [ "${1}" != "" ]
then
    SIZE=${1}
    echo "Set thumbnail size to "${SIZE}
fi


TDIR="../"`basename "${PWD}"`"-tmb_"${SIZE}
if [ ! -e "${TDIR}" ]
then
    echo "Create target dir: "${TDIR}
    mkdir "${TDIR}"
else
    echo "Target dir exists: "${TDIR}
fi


find -wholename "*.jpg" \
     -or -wholename "*.JPG" \
     -or -wholename "*.png" \
     -or -wholename "*.PNG" \
     -or -wholename "*.tif" \
     -or -wholename "*.TIF" \
     -or -wholename "*.tiff" \
     -or -wholename "*.TIFF" | while read i

do
    if [ -e "${i}" ]
    then
        # echo "Processing $i"
        D=`dirname "${i}"`
        ID="${TDIR}/${D}"
        if [ ! -e "${ID}" ]
        then
            echo "Create dir ${ID}"
            mkdir -p "${ID}"
        fi
        F=`basename "${i}"`
        F=`basename "${F}" .jpg`
        F=`basename "${F}" .JPG`
        F=`basename "${F}" .png`
        F=`basename "${F}" .PNG`
        F=`basename "${F}" .tif`
        F=`basename "${F}" .TIF`
        F=`basename "${F}" .tiff`
        F=`basename "${F}" .TIFF`
        
        TF="${ID}/${F}-tmb_${SIZE}.jpg"
        if [ ! -e "${TF}" ]
        then
            echo "Create thumbnail file "${TF}
            nice -19 convert "${i}" -quality 85 -resize ${SIZE}"x"${SIZE} "${TF}"
        else
            echo "Thumbnail file exists "${TF}
        fi

    else
        echo "File not exists: "${i}

    fi 
done


