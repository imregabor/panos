#!/bin/bash
#
# Blend images; recognize recursive multi row directories

set -e
set -o pipefail
set -u


# Check commands
for i in enblend
do
    echo "Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done    

LOG=blend.log


INFILES=p1*.tif
OUTFILE=p1.tif
ENBLOPS="--compression=LZW -v -m 1500 -l 28"
MULTIROW=false

if [ -e `echo row*/ | awk '{ print $1 }'` ]
then
    MULTIROW=true
fi

echo "=======================================================================================================" | tee -a "${LOG}"
echo `date`" Start blending in "`pwd` | tee -a "$LOG"
echo "    INFILES:  "$INFILES | tee -a "$LOG"
echo "    MULTIROW: "$MULTIROW | tee -a "$LOG"
echo "    OUTFILE:  "$OUTFILE | tee -a "$LOG"
echo "    ENBLOPS:  "$ENBLOPS | tee -a "$LOG"
echo "    LOGFILE:  "$LOG | tee -a "$LOG"
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
	    /usr/bin/time -a -o time-$i.txt $0 -log "${LOG}" -nev
	    echo "    Returned, timestamp: "`date` | tee -a "${LOG}"
	    echo "    Time in "$i":" | tee -a "${LOG}"
	    cat time-$i.txt | tee -a "${LOG}"
	    cd ..
	    echo "    Done." | tee -a "${LOG}"
	done

	INFILES=row*/p1.tif
	echo "    INFILES:  "$INFILES | tee -a "$LOG"
    fi
	
    echo "    Start normal blending, timestamp: "`date` | tee -a "${LOG}"

    /usr/bin/time -a -o time.txt enblend -o $OUTFILE $ENBLOPS $INFILES 2>&1 | tee -a "$LOG"
    echo "    Returned, timestamp: "`date` | tee -a "${LOG}"
    echo "    Time in enblend:" | tee -a "${LOG}"
    cat time.txt | tee -a "${LOG}" 
fi


