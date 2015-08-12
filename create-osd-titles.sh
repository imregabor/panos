#!/bin/bash
#
# Create openseadragon titles
#
#
set -e
set -o pipefail
set -u

for i in convert identify
do
    echo "Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done    

if [ $# -ne 1 ] ; then echo "Specify image to process." ; exit -1 ; fi
if [ ! -e "$1" ] ; then echo "Input image \"$1\" not found." ; exit -1 ; fi

B=$(basename "$1" .tif)
B=$(basename "$B" .TIF)
B=$(basename "$B" .jpg)
B=$(basename "$B" .JPG)
B=$(basename "$B" .jpeg)
B=$(basename "$B" .JPEG)
B=$(basename "$B" .png)
B=$(basename "$B" .PNG)
B=$(echo "$B" | tr " " "_")
echo "Image basename: $B"


T=2048

echo "Tile size:      $T"



processSingleLevel() {
    echo 
    echo "--------------------------------------------------"
    echo "Process single level image $1"
    echo "--------------------------------------------------"
    echo
    echo
    
    echo "    Check image dimensions:"
    W=$(identify -format "%w" "$1")
    H=$(identify -format "%h" "$1")
    echo "        w: $W h: $H"
    if [ $W -lt 1 ] || [ $H -lt 1 ]; then echo "Invalid image dimensions $W x $H." ; exit -1 ; fi

    if [ $W -gt $H ] ; then G=$W ; else G=$H ; fi
    echo "        greater: $G"

    L=0 ; I=1; while [ $G -gt $I ] ; do L=$((L + 1)) ; I=$((I * 2)) ; done
    echo "        image level: $L"



    mkdir -p "${B}_files/${L}"

    echo "    Create tiles"
    
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
            
            
            
            OF="${B}_files/${L}/${X}_${Y}.jpg"
            
            echo "        X: $X X1: $X1 Y: $Y Y1: $Y1 CW: $CW CH: $CH OF: $OF"
            
            if [ ! -e "${OF}" ]
            then
                convert -crop "${CW}x${CH}+${X1}+${Y1}" "$1" -quality 90 "${OF}"
            fi

            X=$(($X + 1))
        done
        Y=$(($Y + 1))
    done

} # processSingleLevel

processSingleLevel "$1"

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\
<Image xmlns=\"http://schemas.microsoft.com/deepzoom/2008\" Format=\"jpg\" Overlap=\"0\" TileSize=\"${T}\">\
    <Size Width=\"${W}\" Height=\"${H}\"/>\
</Image>" > "${B}.dzi"



IN="$1"
while true ; do
    
    
    if [ $L -lt 5 ]
    then
        echo "Done."
        break
    fi
    
    NW=$(($W >> 1))
    NH=$(($H >> 1))
    if [ $NW -lt 1 ] ; then NW=1 ; fi
    if [ $NH -lt 1 ] ; then NH=1 ; fi
    
    OUT="tmp-L-"$(($L - 1))".jpg"
    SIZ=${NW}x${NH}
    
    echo
    echo
    echo "Next level: ${OUT} with ${SIZ}"
    echo
    echo
    
    
    convert -resize ${SIZ} "${IN}" "${OUT}"
    IN="${OUT}"
    
    processSingleLevel "${IN}"
done