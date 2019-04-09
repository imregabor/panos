#!/bin/bash

rm files.txt
for i in *.MOV
do
    if [ ! -e "$i" ]
    then
        echo "Input files not found. Exiting."
        exit -1
    fi
    echo "file $i" >> files.txt
done

B=timelapse

nice -19 ffmpeg -f concat -i files.txt -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.001*PTS" $B-1000x.mp4
nice -19 ffmpeg -f concat -i files.txt -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.002*PTS" $B-0500x.mp4
nice -19 ffmpeg -f concat -i files.txt -an -vcodec libx264 -b 15000k -r 60 -filter:v "setpts=0.005*PTS" $B-0200x.mp4
nice -19 ffmpeg -f concat -i files.txt -an -vcodec libx264 -b 10000k -r 60 -filter:v "setpts=0.01*PTS" $B-0100x.mp4
nice -19 ffmpeg -f concat -i files.txt -an -vcodec libx264 -b 10000k -r 60 -filter:v "setpts=0.02*PTS" $B-0050x.mp4
nice -19 ffmpeg -f concat -i files.txt -an -vcodec libx264 -b 3000k -r 60 -filter:v "setpts=0.04*PTS" $B-0025x.mp4
nice -19 ffmpeg -f concat -i files.txt -an -vcodec libx264 -b 3000k -r 60 -filter:v "setpts=0.066666666*PTS" $B-0015x.mp4




