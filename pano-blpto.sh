#!/bin/bash
#
# Stitch and blend a pto
#
#

set -e
set -o pipefail
set -u

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
echo -n "Checking available commands:"
for i in nona enblend pto_gen pano_modify cpfind cpclean autooptimiser pto_var vig_optimize convert 
do
  echo -n " $i"
  command -v $i >/dev/null 2>&1 || { echo >&2 " | ERROR: Command $i not found, exiting"; exit 1; }
done
echo
echo "  All commands found"
echo

CONVERTCMD=convert
if command -v magick >/dev/null 2>&1; then
    CONVERTCMD=magick
    echo "Use $CONVERTCMD for imagemagick convert"
fi

echo
echo
echo

INFILE=""
OUTDIR=""
STITCHONLY=false

function usage {
  echo
  echo "Usage: $0 [-h] [-nb]"
  echo
  echo "  -h   Print this usage and exit"
  echo "  -in  Input PTO file"
  echo "  -od  Output dir"
  echo "  -so  Stitch only, no blend"
  echo
  echo
}


# from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]; do
  case $1 in
    -in)
      INFILE="$2"
      shift
      shift
      ;;
    -od)
      OUTDIR="$2"
      shift
      shift
      ;;
    -so)
      STITCHONLY=true
      shift
      ;;
    -h)
      usage
      exit
      ;;
    *)
      echo "ERROR! Unknown option \"$1\""
      usage
      exit 1
      ;;
  esac
done

echo
echo

if [ -z "$INFILE" ] ; then echo >&2 "No input file specified." ; exit 1 ; fi
if [ ! -f "$INFILE" ] ; then echo >&2 "Input file not found: $INFILE" ; exit 1 ; fi
if [ -z "$OUTDIR" ] ; then echo >&2 "No output dir specified." ; exit 1 ; fi
if [ -e "$OUTDIR" ] ; then echo >&2 "Output dir akready exists: $OUTDIR" ; exit 1 ; fi


mkdir -p "$OUTDIR"
LOG="$OUTDIR/pano.log"



STARTSEC=$(date "+%s")



function sect {
  TS=$(date "+%Y-%m-%d %H:%M:%S")
  DT=$(( $(date "+%s") - $STARTSEC ))
  DTF=$(printf "%5d" $DT)
  echo | tee -a "${LOG}"
  echo | tee -a "${LOG}"
  echo "+--[ ${TS}, ${DTF} s ]--------------------------------------------------------------------------------------" | tee -a "${LOG}"
  echo "|" | tee -a "${LOG}"
  while [ $# -gt 0 ] ; do echo "| $1" | tee -a "${LOG}"; shift; done
  echo "|" | tee -a "${LOG}"
  echo "| DT: ${DT} s" | tee -a "${LOG}"
  echo "|" | tee -a "${LOG}" ;
  echo "+------------------------------------------------------------------------------------------------------------------------" | tee -a "${LOG}"
  echo | tee -a "${LOG}" ;
  echo | tee -a "${LOG}"
}

function blprev {
  sect "Launch stitch/blend preview" "Input file: $1" "Output basename: $2" "Output dir: $3"

  if [ ! -e "$1" ]; then
    echo "ERROR! No input pto file specified, exiting"
    exit -1
  fi

  if [ -z "$2" ]; then
    echo "ERROR! No output basename specified, exiting"
    exit -1
  fi

  if [ -z "$3" ]; then
    echo "ERROR! No output dir specified, exiting"
    exit -1
  fi

  mkdir -p "$3"

  # Nona tif prefix
  NONAO="${3}/${2}-"

  # Blended output file
  ENBLO="${3}/${2}-blend.tif"

  JPG="${3}/${2}-blend.jpg"
  JPGSMALL="${3}/${2}-blend-small.jpg"

  sect "Stitch with nona" "NONAO: \"${NONAO}\""
  nona -o "${NONAO}" -m TIFF_m "$1" -v --ignore-exposure 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"


  if [ $STITCHONLY = true ]; then
    return
  fi

  sect "Blend with enblend" "ENBLO: \"${ENBLO}\""
  enblend -v -o "${ENBLO}" "${NONAO}"*.tif 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

  # See https://stackoverflow.com/questions/77578848/imagemagick-throws-width-or-height-exceeds-when-converting-svg-to-png-with-ver
  # JPG conversion still might fail (65500 px width limit)
  sect "Create jpg from last stitch" "ENBLO: \"${ENBLO}\"" "JPG:   \"${JPG}\""
  $CONVERTCMD "${ENBLO}" -quality 100 "${JPG}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}" || true

  sect "Create 20% preview jpg from last stitch" "ENBLO: \"${ENBLO}\"" "JPG:   \"${JPGSMALL}\""
  $CONVERTCMD "${ENBLO}" -resize 20% -quality 100 "${JPGSMALL}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
}

sect "Blend PTO from $INFILE into $OUTDIR" "" "    pwd: $(pwd)" "    so: ${STITCHONLY}"
blprev "$INFILE" p1 "$OUTDIR"

sect "All done."
