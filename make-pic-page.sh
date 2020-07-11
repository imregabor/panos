#!/bin/bash

set -e
# set -o pipefail
set -u


echo "================================================================================================================="
echo
echo "Create pano/pic overview page"
echo
echo "================================================================================================================="

echo
echo "Checking the presence of required tools"
# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
for i in identify convert ant
do
    echo "  Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done
IDENTIFY=identify
CONVERT=convert
ANT=ant

echo "  All tools found."
echo


PWD=$(pwd)
TDIR="../"$(basename "${PWD}")"-imgindex/"
mkdir -p "${TDIR}"



# thumbnail sizes
SIZES="250 400 800 1280 1920 2500 3840"

# Output file
#XML="${TDIR}/index.xml"
XML="./index.xml"



echo
echo "Settings:"
echo "  Target directory: \"${TDIR}\""
echo "  Thumbnail sizes:  $SIZES"
echo "  Index XML:        \"${XML}\""

# Write XML header =====================================================================================================

echo "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>" > "${XML}"
echo "<panopage>" >> "${XML}"
echo "    <!-- Thumbnail sizes (bounding box)  -->" >> "${XML}"
echo "    <sizes>" >> "${XML}"
for S in $SIZES
do
    echo "        <size>"${S}"</size>" >> "${XML}"
done
echo "    </sizes>" >> "${XML}"


echo "    <images>" >> "${XML}"



{ find -type f -name "*.jpg" ; \
  find -type f -name "*.JPG" ; \
  find -type f -name "*.jpeg" ; \
  find -type f -name "*.JPEG" ; \
  find -type f -name "*.png" ; \
  find -type f -name "*.PNG" ; \
  find -type f -name "*.tif" ; \
  find -type f -name "*.TIF" ;  \
  find -type f -name "*.tiff" ; \
  find -type f -name "*.TIFF" ; } | while read i
do
    echo
    echo "-----------------------------------------------------------------------------------------------------"
    echo "Process image \"$i\""
    echo "-----------------------------------------------------------------------------------------------------"
    echo


    #    if [[ "$i" == */zoomify/* || "$i" == */ZOOMIFY/* ]]
    #    then
    #        echo "    Image $i is zoomify file, skip it"
    #        continue
    #    fi

    if [ ! -e "${i}" ] ; then echo "Image not found, continue" ; continue ; fi

    F=`basename "${i}"`
    F=`basename "${F}" .jpg`
    F=`basename "${F}" .JPG`
    F=`basename "${F}" .jpeg`
    F=`basename "${F}" .JPEG`
    F=`basename "${F}" .png`
    F=`basename "${F}" .PNG`
    F=`basename "${F}" .tif`
    F=`basename "${F}" .TIFF`

    ORIG=`echo "${i}" | sed -e "s/.\\///"`

    echo "    F (Image base)          \"${F}\""
    echo "    ORIG (Orig link)        \"${ORIG}\""

    # Basic file info --------------------------------------------------------------------------------------------------
    echo "        <image>" >> "${XML}"
    echo -n "            <original>${ORIG}</original>" >> "${XML}" # Identify seemingly clips leading spaces from format string
    ${IDENTIFY} -format "\n            <width>%w</width>\n            <height>%h</height>" "${i}" >> "${XML}"
    echo "            <size>"`stat --printf="%s" "${i}"`"</size>" >> "${XML}"

    # check for not so important pics folder ---------------------------------------------------------------------------
    if [[ "$i" == */_nti/* || "$i" == */_NTI_/* || "$i" == */_nsi/* || "$i" == */_NSI_/* ]]
    then
        echo "    _nti (not too important)"
        echo "            <nti>true</nti>" >> "${XML}"
    else
        echo "            <nti>false</nti>" >> "${XML}"
    fi

    # check for panorama src/workfile ----------------------------------------------------------------------------------
    if [[ "$i" == */sources/* || "$i" == */SOURCES/* ]]
    then
        echo "    source (panorama) file"
        echo "            <panosource>true</panosource>" >> "${XML}"
    else
        echo "            <panosource>false</panosource>" >> "${XML}"
    fi
    if [[ "$i" == */workfiles/* || "$i" == */WORKFILES/* ]]
    then
        echo "    panorama workfile"
        echo "            <panoworkfile>true</panoworkfile>" >> "${XML}"
    else
        echo "            <panoworkfile>false</panoworkfile>" >> "${XML}"
    fi

    # cache / store EXIF data ==========================================================================================
    EXIFDIR="${TDIR}/exif"
    SUBDIR="${EXIFDIR}/"`dirname "${i}"`/
    SUBDIR=$(echo "${SUBDIR}" | sed -e "s/\\/.\\//\\//" | sed -e "s/\\/\\//\\//")
    TF="${SUBDIR}${F}.exif"
    TFX="${SUBDIR}${F}.exif.xmlpart"

    echo "    EXIF cache subdir:      \"${SUBDIR}\""
    echo "    EXIF cache file:        \"${TF}\""
    echo "    EXIF XML fragment file: \"${TFX}\""
    mkdir -p "${SUBDIR}"

    if [ ! -e "$TF" ]
    then
        echo "    Exif cache file not found; launch identity to check / extract EXIF header"
        EXIF=`${IDENTIFY} -format "%[exif:*]" "${i}"`
        echo $EXIF > "$TF"
        if [ "${EXIF}" != "" ]
        then
            echo "        Exif in image file found; retrieve Exif XML fragment"
            echo "            <exif>" > "$TFX"
            ${IDENTIFY} -format "%[exif:*]" "${i}" | grep -v "^$" | sed -e "s/^exif://" | tr "=" " " | awk '{ printf "                <%s>",$1 ; for(i=2;i<=NF;i++) { printf i==2?"%s":" %s",$i ; } printf "</%s>\n",$1 ; }' >> "$TFX"
            echo "            </exif>" >> "$TFX"
        fi
    fi

    if [ -e "${TFX}" ]
    then
        cat "$TFX" | sed -e 's/thumbnail:/thumbnail-/g' >> "${XML}"
    fi

    TMBDIR="${TDIR}/thumbnail"
    # Create / reference thumbnails ====================================================================================
    for S in $SIZES
    do
        #TMBDIR="${TDIR}/tmb-${S}"
        SUBDIR="${TMBDIR}/"`dirname "${i}"`/
        SUBDIR=`echo ${SUBDIR} | sed -e "s/\\/.\\//\\//" | sed -e "s/\\/\\//\\//"`
        TF="${SUBDIR}${F}-tmb-${S}.jpg"
        mkdir -p "${SUBDIR}"

        echo "        Thumbnail ${S} x ${S}:"
        echo "            Subdir:         ${SUBDIR}"
        echo "            Thumbnail file: ${TF}"

        echo "            <thumbnail size=\""${S}"\">" >> "${XML}"
        echo -n "                <file>"${TF}"</file>" >> "${XML}" # Subsequent identify space clipping

        if [ ! -e "${TF}" ]
	then
	    echo "            Thumbnail missing, create"

            # auto orient thumbnails
            # see http://stackoverflow.com/questions/19456036/detect-exif-orientation-and-rotate-image-using-imagemagick
            nice -19 ${CONVERT} "${i}" -auto-orient -quality 85 -resize ${S}"x"${S} "${TF}"
        fi

        ${IDENTIFY} -format '\n                <width>%w</width>\n                <height>%h</height>' "${TF}" >> "${XML}"
        echo "                <size>"`stat --printf="%s" "${TF}"`"</size>" >> "${XML}"

	echo "            </thumbnail>" >> "${XML}"

    done

    # Close image tag
    echo "        </image>" >> "${XML}"

done


echo "    </images>" >> "${XML}"
echo "</panopage>" >> "${XML}"


echo "Translate "${XML}
# process summary
cp `dirname $0`/pic-page-build.xml .
cp `dirname $0`/pic-page-style.xslt .
ant -f pic-page-build.xml -Douthtml=index.html picpage
