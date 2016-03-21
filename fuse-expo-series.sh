#!/bin/bash

set -e

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
for i in enfuse
do
    echo "Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done



COUNT=5

mkdir -p fused/

if [ ! -d "expo-series" ]
then
    echo "Source directory \"expo-series\" not found."
    exit -1
fi

ct=1

find -wholename "./expo-series/*.JPG" -or -wholename "./expo-series/*.jpg" | sort | while read line
do
    infiles=$line
    for i in `seq 2 $COUNT`
    do
	read l2
	infiles="$infiles $l2"
    done
    of=`printf "./fused/fused%05d.jpg" $ct`
    echo
    echo
    echo
    echo "================================================================================================================="
    echo "FUSING $of from sources $infiles"
    echo "================================================================================================================="
    echo
    enfuse -v -o "$of" --compression 0 $infiles


    ct=`expr $ct + 1`

done