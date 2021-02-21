#!/bin/bash
#
# Create openseadragon-compatible DZI image pyramid titles
#
# See:
#    https://openseadragon.github.io/
#    https://openseadragon.github.io/examples/tilesource-dzi/
#    https://msdn.microsoft.com/en-us/library/cc645077%28v=vs.95%29.aspx
#    https://msdn.microsoft.com/en-us/library/cc645022%28v=vs.95%29.aspx

set -e
set -o pipefail
set -u

#
# Check tools to bo used
#
for i in convert identify
do
    echo "Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done

usage() {
    echo "usage:"
    echo
    echo "    $0 -i <INPUTFILE> -o <OUTPUTPREFIX> [-t <TITLESIZE>]"
    echo
}

#
# Default values; pars CLI argumentgs
#

IN=""
OUT=""
T=2048

while getopts "i:o:t:" OPTION ; do
    case $OPTION in
    i) IN="${OPTARG}" ;;
    o) OUT="${OPTARG}" ;;
    t) T="${OPTARG}" ;;
    *) usage ; exit -1 ;;
esac ; done

if [ -z "${IN}" ] ; then echo "Input not specified; use -i <INFILE>" ; exit -1 ; fi
if [ -z "${OUT}" ] ; then echo "Output prefix is not specified; use -o <OUTPUTPREFIX>" ; exit -1 ; fi
if [ ! -e "${IN}" ] ; then echo "Input image \"${IN}\" not found." ; exit -1 ; fi

DZI="${OUT}.dzi"


echo "------------------------------------------------------------------------------------"
echo "Create image pyramid titles"
echo
echo "   Input image:    \"$IN\""
echo "   Output prefix:  \"$OUT\""
echo "   Tile size:      $T"
echo "   DZI file:       \"$DZI\""
echo "------------------------------------------------------------------------------------"
echo
echo


processSingleLevel() {
    echo 
    echo "--------------------------------------------------"
    echo "Process single level image $1"
    echo "--------------------------------------------------"
    echo
    echo

    # Retrieve and check image dimensions

    echo "    Check image dimensions:"
    W=$(identify -format "%w" "$1")
    H=$(identify -format "%h" "$1")
    echo "        w: $W h: $H"
    if [ $W -lt 1 ] || [ $H -lt 1 ]; then echo "Invalid image dimensions $W x $H." ; exit -1 ; fi

    if [ $W -gt $H ] ; then G=$W ; else G=$H ; fi
    echo "        greater: $G"

    # Determine image level

    L=0 ; I=1; while [ $G -gt $I ] ; do L=$((L + 1)) ; I=$((I * 2)) ; done
    echo "        image level: $L"


    OUTDIR="${OUT}_files/${L}"
    mkdir -p "${OUTDIR}"

    echo "    Create tiles into output directory \"${OUTDIR}\""
    
    Y=0
    while true ; do
        Y1=$((Y * T))
        if [ $Y1 -gt $H ] || [ $Y1 -eq $H ] ; then break; fi

        CH=$((H - $Y1)) ; if [ $CH -gt $T ] ; then CH=$T ; fi
        

        X=0
        while true ; do
            X1=$((X * T))
            if [ $X1 -gt $W ] || [ $X1 -eq $W ] ; then break; fi
            CW=$((W - $X1)) ; if [ $CW -gt $T ] ; then CW=$T ; fi
            
            
            
            OF="${OUTDIR}/${X}_${Y}.jpg"
            
            echo "        Tile index: X: $X Y: $Y Tile upper left corner: X1: $X1  Y1: $Y1 Tile size: CW: $CW CH: $CH Output file: $OF"
            
            if [ ! -e "${OF}" ]
            then
                CROPOPT="${CW}x${CH}+${X1}+${Y1}"
                echo "            Crop option ${CROPOPT}"
                convert -crop "${CROPOPT}" "$1" -quality 90 "${OF}"
            fi

            X=$(($X + 1))
        done
        Y=$(($Y + 1))
    done

    echo "        Tiles created."
} # processSingleLevel

processSingleLevel "$IN"

# Write DZI file containing image dimensions
echo -e "<?xml version='1.0' encoding='UTF-8'?>\n\
<!-- This is an auto generated DZI file -->\n\
<Image xmlns='http://schemas.microsoft.com/deepzoom/2008' Format='jpg' Overlap='0' TileSize='${T}'>\n\
    <Size Width='${W}' Height='${H}'/>\n\
</Image>" > "${DZI}"

# Write index HTML
echo -e "<!DOCTYPE html>\n\
<html>\n\
<head>\n\
    <title>Zoomable image</title>\n\
    <script src='js/openseadragon-bin-2.4.2/openseadragon.min.js'></script>\n\
</head>\n\
<body>\n\
    <div id='img' style='position: fixed; top: 0; left: 0; bottom: 0; right: 0'></div>\n\
    <script type='text/javascript'>\n\
        // For options doc see http://openseadragon.github.io/docs/OpenSeadragon.html#.Options\n\
        OpenSeadragon({\n\
            id:                'img',\n\
            prefixUrl:         'js/openseadragon-bin-2.4.2/images/',\n\
            tileSources:       '${OUT}.dzi',\n\
            maxZoomPixelRatio: 10,\n\
        });\n\
    </script>\n\
</body>" > "${OUT}.html"

# Create JS dir
if [ ! -d "js/" ]
then
    mkdir js/
    # wget https://github.com/openseadragon/openseadragon/releases/download/v2.0.0/openseadragon-bin-2.0.0.tar.gz -O - | tar -xz -C js/
    wget https://github.com/openseadragon/openseadragon/releases/download/v2.4.2/openseadragon-bin-2.4.2.tar.gz -O - | tar -xz -C js/
fi


# Process further levels
while true ; do
    
    # Do not descend into too small levels
    if [ $L -lt 1 ]
    then
        echo "Done."
        break
    fi
    
    NW=$(($W >> 1))
    NH=$(($H >> 1))
    if [ $NW -lt 1 ] ; then NW=1 ; fi
    if [ $NH -lt 1 ] ; then NH=1 ; fi
    
    mkdir -p "${OUT}_tmbs"
    TMB="${OUT}_tmbs/L-"$(($L - 1))".jpg"
    SIZ=${NW}x${NH}
    
    echo 
    echo "--------------------------------------------------"
    echo "Create next level tiling"
    echo
    echo "    Current level: $L"
    echo "    Current size:  $W x $H"
    echo "    Next size:     $NW x $NH"
    echo
    echo "    Resze arg:     $SIZ"
    echo "    Thumbnail:     $TMB"
    echo "--------------------------------------------------"
    echo
    echo

    if [ ! -e "${TMB}" ]
    then
        convert -resize ${SIZ} "${IN}" "${TMB}"
    fi
    IN="${TMB}"

    processSingleLevel "${IN}"
done
