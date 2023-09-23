#!/bin/bash
#
# Convert input to 16 bit PCM signed big endian stream
#
# See https://trac.ffmpeg.org/wiki/audio%20types
# And https://stackoverflow.com/questions/4854513/can-ffmpeg-convert-audio-to-raw-pcm-if-so-how

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg not found"; exit 1; }

INFILE=$1
OUTFILE=$2

if [ -z "${INFILE}" ] ; then echo >&2 "No infile specified" ; exit 1; fi
if [ -z "${OUTFILE}" ] ; then echo >&2 "No outfile specified" ; exit 1; fi

if [ ! -f "${INFILE}" ] ; then echo >&2 "Infile ${INFILE} not found" ; exit 1; fi
if [ -e "${OUTFILE}" ] ; then echo >&2 "Outfile ${OUTFILE} already exists" ; exit 1; fi

ffmpeg -y -i "${INFILE}" -acodec pcm_s16be -f s16be -ac 1 -ar 16000 "${OUTFILE}"
