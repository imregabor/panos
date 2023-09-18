#!/bin/bash
#
# Blend images; recognize recursive multi row directories

set -e
set -o pipefail
set -u

# ImageMagick's convert might be magick
if command -v magick >/dev/null 2>&1
then
    CONVERT=magick
	echo "Use magick for ImageMagick convert"
elif command -v convert >/dev/null 2>&1
then
    CONVERT=convert
	echo "Use convert for ImageMagick convert"
else
    echo 2>&2 "convert (magick) not found"
	exit 1
fi


# Check commands
for i in enblend convert time
do
    echo "Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done    

LOG=blend.log

THISSCRIPT=`readlink -m "$0"`
INFILES=p1*.tif
OUTFILE=p1.tif
OUTFILEJPG=p1.jpg
OUTFILEPRV=p1-small.jpg
ENBLOPS="--compression=LZW -v -l 28"
MULTIROW=false
DOJPG=true

if [[ $# -gt 0 && $1 == "--nojpg" ]]
then
    echo "Wont do JPG"
    DOJPG=false
fi

if [ -e `echo row*/ | awk '{ print $1 }'` ]
then
    MULTIROW=true
fi

echo "=======================================================================================================" | tee -a "${LOG}"
echo `date`" Start blending in "`pwd` | tee -a "$LOG"
echo "    INFILES:    "$INFILES | tee -a "$LOG"
echo "    MULTIROW:   "$MULTIROW | tee -a "$LOG"
echo "    OUTFILE:    "$OUTFILE | tee -a "$LOG"
echo "    ENBLOPS:    "$ENBLOPS | tee -a "$LOG"
echo "    LOGFILE:    "$LOG | tee -a "$LOG"
echo "    CONVERT:    "$CONVERT | tee -a "$LOG"
echo "    THISSCRIPT: "$THISSCRIPT | tee -a "$LOG"
echo  | tee -a "$LOG"

echo "    Enblend version/help:" | tee -a "${LOG}"
enblend -V | tee -a "${LOG}"


if [ -e "$OUTFILE" ]
then
    echo "    Output file exists, exiting." | tee -a "$LOG"
else
    if [ $MULTIROW = true ]
    then
	echo "    Start multirow blending" | tee -a "${LOG}"
	for i in row*
	do
	    echo "    Blend in "$i" timestamp: "`date` | tee -a "${LOG}"
	    cd $i
	    "${THISSCRIPT}" -log "${LOG}" -nev
	    echo "    Returned, timestamp: "`date` | tee -a "${LOG}"
	    # echo "    Time in "$i":" | tee -a "${LOG}"
	    # cat time-$i.txt | tee -a "${LOG}"
	    cd ..
	    echo "    Done." | tee -a "${LOG}"
	done

	INFILES=row*/p1.tif
	echo "    INFILES:  "$INFILES | tee -a "$LOG"
    fi
	
    echo "    Start normal blending, timestamp: "`date` | tee -a "${LOG}"

    enblend -o $OUTFILE $ENBLOPS $INFILES 2>&1 | tee -a "$LOG"
    echo "    Returned, timestamp: "`date` | tee -a "${LOG}"
    # echo "    Time in enblend:" | tee -a "${LOG}"
    # cat time.txt | tee -a "${LOG}" 

    if [ ! -e "$OUTFILEJPG" ] && [ $DOJPG ]
    then    
        echo "    Convert to jpg" | tee -a "${LOG}"
        "${CONVERT}" "$OUTFILE" -quality 100 "$OUTFILEJPG"
    fi
    
    if [ ! -e "$OUTFILEPRV" ] && [ $DOJPG ]
    then    
        echo "    Convert to a 20% preview jpg" | tee -a "${LOG}"
        "${CONVERT}" "$OUTFILE" -quality 100 -resize 20% "$OUTFILEPRV"    
    fi
fi


