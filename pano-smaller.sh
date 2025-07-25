#!/bin/bash
#
# Prepare smaller panorama which does not wrap around
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

show_pano_layout_py="$(dirname "$0")/show-pano-layout.py"
echo
echo -n " $show_pano_layout_py"
if [ ! -f "$show_pano_layout_py" ] ; then
  echo >&2 " | ERROR: script not found, exiting"
  exit 1
fi

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

DOBLEND=true
DOSHOWLAYOUT=true
FIRSTANCHOR=false

function usage {
  echo
  echo "Usage: $0 [-h] [-nb]"
  echo
  echo "  -h   Print this usage and exit"
  echo "  -nb  Skip stitching and blending final panorama"
  echo "  -nl  Skip rendering layout image"
  echo "  -fa  Use first image as anchor instead of the middle one"
  echo
  echo
}


# from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]; do
  case $1 in
    -nb)
      DOBLEND=false
      echo "Will not stitch / blend"
      shift
      ;;
    -fa)
      FIRSTANCHOR=true
      echo "Will use first image as anchor instead of the middle one"
      shift
      ;;
    -nl)
      DOSHOWLAYOUT=false
      echo "Will not render layout image"
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


LOG=pano.log

# Initial settings
# PMFOV=""
# PMCRP=""
# PMCTR=""

PMFOV="--fov=AUTO"
PMCRP="--crop=AUTO"
PMCTR="--center"
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
  sect "Launch stitch/blend preview" "pwd: $(pwd)" "Input file: $1" "Output basename: $2"

  if [ ! -e "$1" ]; then
    echo "ERROR! No input pto file specified, exiting"
    exit -1
  fi

  if [ -z "$2" ]; then
    echo "ERROR! No output basename specified, exiting"
    exit -1
  fi

  if [ ! -d "workfiles" ] ; then
    echo "Create workfiles/ dir"
    mkdir workfiles/
  fi

  # Nona tif prefix
  #NONAO=workfiles/`basename "${PO}" ".pto"`-
  NONAO="workfiles/${2}-"

  # Blended output file
  #ENBLO=workfiles/`basename "${PO}" ".pto"`-blend.tif
  ENBLO="workfiles/${2}-blend.tif"

  JPG="workfiles/${2}-blend.jpg"

  sect "Stitch with nona" "pwd: $(pwd)" "NONAO: \"${NONAO}\""
  nona -o "${NONAO}" -m TIFF_m "${PO}" -v --ignore-exposure 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

  sect "Blend with enblend" "pwd: $(pwd)" "ENBLO: \"${ENBLO}\""
  enblend -v -o "${ENBLO}" "${NONAO}"*.tif 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

  sect "Create jpg from last stitch" "pwd: $(pwd)" "ENBLO: \"${ENBLO}\"" "JPG:   \"${JPG}\""
  $CONVERTCMD "${ENBLO}" -quality 100 "${JPG}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
}

sect "Prepare panorama initial workflow" "    pwd: $(pwd)"

if [ ! -d "sources/" ]
then
    echo "Create sources/ dir; move sources"
    mkdir sources/
    mv *.[jJ][pP][gG] sources/
fi

# input PTO file
PI=""
PO=""
# panorama out counter
POCT=0;

# roll PTO files
#  $1 - short name, will be part of new output file name
#  $2 - description, will be printed 
function newPto() {
  if [ -z "$1" ]; then
    echo "ERROR: No short name specified, exiting."
    exit -1
  fi

  if [ -z "$2" ]; then
    echo "ERROR: No human readable description specified, exiting."
    exit -1
  fi

  PI="${PO}"
  PO="sources/pano-$(printf '%02d' $POCT)-$1.pto"
  POCT=$(( $POCT + 1))
  sect "$2" "  pwd: $(pwd)" "  PI:  ${PI}" "  PO:  ${PO}"
}


if [ "$FIRSTANCHOR" = true ] ; then
  echo "Use first image as anchor"
  ANCHORNUM=0
else

  # see https://stackoverflow.com/questions/21143043/find-count-of-files-matching-a-pattern-in-a-directory-in-linux
  IMGCOUNT=$(ls -1 sources/*.[jJ][pP][gG] | wc -l)
  ANCHORNUM=$(( $IMGCOUNT / 2 ))

  echo "Use middle image as anchor. IMGCOUNT=${IMGCOUNT}, ANCHORNUM=${ANCHORNUM}"
fi





newPto "initial" "pto-gen from source JPGs"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  pto_gen -o "${PO}" sources/*.[jJ][pP][gG] 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "initial-c" "modify canvas size to fov 360 x 180 4k x 2k"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  pano_modify -o "${PO}" --fov=360x180 --canvas=4000x2000 "${PI}"         2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "cpfind" "cpfind"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  cpfind -o "${PO}" --multirow "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "celeste" "celeste"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  celeste_standalone -i "${PI}" -o "${PO}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "cpclean" "cpclean"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  cpclean -o "${PO}" "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "anchor" "set anchor image to ${ANCHORNUM}"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  pto_var -o "${PO}" "--anchor=${ANCHORNUM}" "--color-anchor=${ANCHORNUM}" "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "pwopted" "do pairwise optimization"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  autooptimiser -p -o "${PO}" "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "pwopted-m" "modify: straighten, center, fov"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  pano_modify -o "${PO}" --straighten $PMCTR $PMFOV $PMCRP "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "geomopt" "set geometry optimization"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  pto_var -o "${PO}" --opt y,p,r,v,a,b,c "${PI}"   2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "geomopted" "do geometry optimization"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  autooptimiser -n -o "${PO}" "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

newPto "geomopted-m" "modify: straighten, center, fov"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  pano_modify -o "${PO}" --straighten $PMCTR $PMFOV $PMCRP "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi


# newPto "vignopt" "set photometric optimization (vignetting)"
# pto_var -o "${PO}" --modify-opt --opt Ra,Rb,Rc,Rd,Re,Vb,Vc,Vd,Vx,Vy "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
#
# newPto "vignopted" "do photometric optimization"
# vig_optimize -o "${PO}" -v -p 5000 "${PI}"    2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "final" "set final canvas size and crop"
if [ -f "${PO}" ] ; then echo "  Output file ${PO} exists; skipping" ; else
  pano_modify -o "${PO}" --straighten $PMCTR --canvas=AUTO $PMFOV $PMCRP "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
fi

if [ "$DOSHOWLAYOUT" = true ] ; then
  LAYOUT_PNG="${PO%.pto}-layout.png"
  sect "Create layout visualization" "  pwd: $(pwd)" "  input: ${PO}" "  Output: ${LAYOUT_PNG}"
  if [ -f "${LAYOUT_PNG}" ]; then echo "  Output file ${LAYOUT_PNG} exists; skipping" ; else
    "$show_pano_layout_py" -i "${PO}" -o "${LAYOUT_PNG}"
  fi
else
  echo
  echo
  echo "Skipping layout visualization"
  echo
  echo
fi

if [ "$DOBLEND" = true ] ; then
  # Final blend
  blprev "${PO}" p1
else
  echo
  echo
  echo "Skipping stitch/blend"
  echo
  echo
fi

sect "All done."
