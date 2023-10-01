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
  command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done
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

function usage {
  echo
  echo "Usage: $0 [-h] [-nb]"
  echo
  echo "  -h   Print this usage and exit"
  echo "  -nb  Skip stitching and blending final panorama"
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
  sect "Launch stitch/blend preview" "Input file: $1" "Output basename: $2"

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

  sect "Stitch with nona" "NONAO: \"${NONAO}\""
  nona -o "${NONAO}" -m TIFF_m "${PO}" -v --ignore-exposure 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

  sect "Blend with enblend" "ENBLO: \"${ENBLO}\""
  enblend -v -o "${ENBLO}" "${NONAO}"*.tif 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

  sect "Create jpg from last stitch" "ENBLO: \"${ENBLO}\"" "JPG:   \"${JPG}\""
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
  sect "$2" "  PI: ${PI}" "  PO: ${PO}"
}

newPto "initial" "pto-gen from source JPGs"
pto_gen -o "${PO}" sources/*.[jJ][pP][gG] 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "initial-c" "modify canvas size to fov 360 x 180 4k x 2k"
pano_modify -o "${PO}" --fov=360x180 --canvas=4000x2000 "${PI}"         2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "cpfind" "cpfind"
cpfind -o "${PO}" --multirow "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "celeste" "celeste"
celeste_standalone -i "${PI}" -o "${PO}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "cpclean" "cpclean"
cpclean -o "${PO}" "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "pwopted" "do pairwise optimization"
autooptimiser -p -o "${PO}" "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "pwopted-m" "modify: straighten, center, fov"
pano_modify -o "${PO}" --straighten $PMCTR $PMFOV $PMCRP "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "geomopt" "set geometry optimization"
pto_var -o "${PO}" --opt y,p,r,v,a,b,c "${PI}"   2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "geomopted" "do geometry optimization"
autooptimiser -n -o "${PO}" "${PI}" 2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "geomopted-m" "modify: straighten, center, fov"
pano_modify -o "${PO}" --straighten $PMCTR $PMFOV $PMCRP "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"


# newPto "vignopt" "set photometric optimization (vignetting)"
# pto_var -o "${PO}" --modify-opt --opt Ra,Rb,Rc,Rd,Re,Vb,Vc,Vd,Vx,Vy "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"
#
# newPto "vignopted" "do photometric optimization"
# vig_optimize -o "${PO}" -v -p 5000 "${PI}"    2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"

newPto "final" "set final canvas size and crop"
pano_modify -o "${PO}" --straighten $PMCTR --canvas=AUTO $PMFOV $PMCRP "${PI}"  2>&1 | sed -ue "s/^/    /" | tee -a "${LOG}"


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
