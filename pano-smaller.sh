#!/bin/bash
#
# Prepare smaller panorama which does not wrap around
#
#

set -e
set -o pipefail
set -u

# see http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
for i in nona enblend pto_gen pano_modify cpfind cpclean autooptimiser pto_var vig_optimize convert 
do
    echo "Checking command $i"
    command -v $i >/dev/null 2>&1 || { echo >&2 "$i not found"; exit 1; }
done    


LOG=pano.log

# Initial settings
# PMFOV=""
# PMCRP=""
# PMCTR=""

PMFOV="--fov=AUTO"
PMCRP="--crop=AUTO"
PMCTR="--center"

function sect {
    echo | tee -a "${LOG}" ; echo | tee -a "${LOG}" ; echo "+------------------------------------------------------------------------------------------" | tee -a "${LOG}" ; echo "|" | tee -a "${LOG}"
    while [ $# -gt 0 ] ; do echo "| $1" | tee -a "${LOG}"; shift; done
    echo "| "$(date "+%Y-%m-%d %H:%M:%S") | tee -a "${LOG}"
    echo "|" | tee -a "${LOG}" ; echo "+-------------------------------------------------------------------------------------------" | tee -a "${LOG}" ; echo | tee -a "${LOG}" ; echo | tee -a "${LOG}"
}

function blprev {
    sect "Launch stitch/blend preview" "Input file: \"$1\"" 

    if [ ! -d "workfiles" ] ; then     echo "Create workfiles/ dir"
        mkdir workfiles/
    fi

    # Nona tif prefix
    NONAO=workfiles/`basename "${PO}" ".pto"`-

    # Blended output file
    ENBLO=workfiles/`basename "${PO}" ".pto"`-blend.tif

    sect "Stitch with nona" "NONAO: \"${NONAO}\"" ; nona -o "${NONAO}" -m TIFF_m "${PO}" 
    sect "Blend with enblend" "ENBLO: \"${ENBLO}\"" ; enblend -o "${ENBLO}" "${NONAO}"*.tif
}


sect "Prepare panorama initial workflow" "pwd: "`pwd`


if [ ! -d "sources/" ]
then
    echo "Create sources/ dir; move sources"
    mkdir sources/
    
    mv *.[jJ][pP][gG] sources/
fi



             PO=sources/pano-00-initial.pto     ; sect "pto-gen from JPGs"         "PO: ${PO}"             ; pto_gen -o "${PO}" sources/*.[jJ][pP][gG]                                                   2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-01-initial-c.pto   ; sect "modify canvas size"        "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --fov=360x180 --canvas=4000x2000 "${PI}"                             2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-02-cp.pto          ; sect "cpfind"                    "PI: ${PI}" "PO: ${PO}" ; cpfind -o "${PO}" --multirow "${PI}"                                                                   2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-03-celeste.pto     ; sect "celeste"                   "PI: ${PI}" "PO: ${PO}" ; celeste_standalone -i "${PI}" -o "${PO}"                                                    2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-04-cpclean.pto     ; sect "cpclean"                   "PI: ${PI}" "PO: ${PO}" ; cpclean -o "${PO}" "${PI}"                                                                  2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-05-pwopted.pto     ; sect "do pairwise optimization"  "PI: ${PI}" "PO: ${PO}" ; autooptimiser -p -o "${PO}" "${PI}"                                                         2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-06-pwopted-m.pto   ; sect "modify: str; cnt; fov"     "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --straighten $PMCTR $PMFOV $PMCRP "${PI}"                             2>&1 | tee -a "${LOG}"
# blprev "${PO}"
PI="${PO}" ; PO=sources/pano-07-geomopt.pto     ; sect "set geomopt"               "PI: ${PI}" "PO: ${PO}" ; pto_var -o "${PO}" --opt y,p,r,v,a,b,c "${PI}"                                              2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-08-geomopted.pto   ; sect "do geomopt"                "PI: ${PI}" "PO: ${PO}" ; autooptimiser -n -o "${PO}" "${PI}"                                                         2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-09-geomopted-m.pto ; sect "modify"                    "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --straighten $PMCTR $PMFOV $PMCRP "${PI}"                             2>&1 | tee -a "${LOG}"
# blprev "${PO}"
PI="${PO}" ; PO=sources/pano-10-vignopt.pto     ; sect "set photoopt (vign)"       "PI: ${PI}" "PO: ${PO}" ; pto_var -o "${PO}" --modify-opt --opt Ra,Rb,Rc,Rd,Re,Vb,Vc,Vd,Vx,Vy "${PI}"                 2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-11-vignopted.pto   ; sect "do photometric opt"        "PI: ${PI}" "PO: ${PO}" ; vig_optimize -o "${PO}" -v -p 5000 "${PI}"                                                  2>&1 | tee -a "${LOG}"
# blprev "${PO}"
PI="${PO}" ; PO=sources/pano-12-modified.pto    ; sect "final modify"              "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --straighten $PMCTR --canvas=AUTO $PMFOV $PMCRP "${PI}"   2>&1 | tee -a "${LOG}"

# Final blend
blprev "${PO}"

p=$(pwd)
f=$(basename "${p}")" - ["$(basename "${PO}" ".pto")"].jpg"

sect "Create jpg from last stitch" "ENBLO: \"${ENBLO}\"" "f:     \"${f}\""
convert "${ENBLO}" -quality 100 "${f}" 2>&1 | tee -a "${LOG}"


sect "All done."
