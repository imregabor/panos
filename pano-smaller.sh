#!/bin/bash
#
# Prepare smaller panorama which does not wrap aroun
#
#

LOG=pano.log

# Initial settings
# PMFOV=""
# PMCRP=""

PMFOV="--fov=AUTO"
PMCRP="--crop=AUTO"

function sect {
    echo | tee -a "${LOG}" ; echo | tee -a "${LOG}" ; echo "+------------------------------------------------------------------------------------------" | tee -a "${LOG}" ; echo "|" | tee -a "${LOG}"
    if [ ! -z "$1" ] ; then echo "| $1" | tee -a "${LOG}" ; fi
    if [ ! -z "$2" ] ; then echo "| $2" | tee -a "${LOG}" ; fi
    if [ ! -z "$3" ] ; then echo "| $3" | tee -a "${LOG}" ; fi
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

    sect "Stitch with nona" "NONAO: \"${NONAO}\"" ; nona -o "${NONAO}" -m TIFF_m "${PO}" ; nona -o p-07-photometric-part- -m TIFF_m pano-07-photometric.pto
    sect "Blend with enblend" "ENBLO: \"${ENBLO}\"" ; enblend -o "${ENBLO}" "${NONAO}"*.tif
}


sect "Prepare panorama initial workflow" "pwd: "`pwd`


if [ ! -d "sources/" ]
then
    echo "Create sources/ dir; move sources"
    mkdir sources/
    mv *.JPG sources/
fi



             PO=sources/pano-00-initial.pto     ; sect "pto-gen from JPGs"         "PO: ${PO}"             ; pto_gen -o "${PO}" sources/*.JPG                                                            2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-01-initial-c.pto   ; sect "modify canvas size"        "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --fov=360x180 --canvas=4000x2000 "${PI}"                             2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-02-cp.pto          ; sect "cpfind"                    "PI: ${PI}" "PO: ${PO}" ; cpfind -o "${PO}" --multirow "${PI}"                                                                   2>&1 | tee -a "${LOG}"
# PI="${PO}" ; PO=sources/pano-03-celeste.pto     ; sect "celeste"                   "PI: ${PI}" "PO: ${PO}" ; celeste_standalone -i "${PI}" -o "${PO}"                                                    2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-04-cpclean.pto     ; sect "cpclean"                   "PI: ${PI}" "PO: ${PO}" ; cpclean -o "${PO}" "${PI}"                                                                  2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-05-pwopted.pto     ; sect "do pairwise optimization"  "PI: ${PI}" "PO: ${PO}" ; autooptimiser -p -o "${PO}" "${PI}"                                                         2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-06-pwopted-m.pto   ; sect "modify: str; cnt; fov"     "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --straighten --center $PMFOV $PMCRP "${PI}"                             2>&1 | tee -a "${LOG}"
# blprev "${PO}"
PI="${PO}" ; PO=sources/pano-07-geomopt.pto     ; sect "set geomopt"               "PI: ${PI}" "PO: ${PO}" ; pto_var -o "${PO}" --opt y,p,r,v,a,b,c "${PI}"                                              2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-08-geomopted.pto   ; sect "do geomopt"                "PI: ${PI}" "PO: ${PO}" ; autooptimiser -n -o "${PO}" "${PI}"                                                         2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-09-geomopted-m.pto ; sect "modify"                    "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --straighten --center $PMFOV $PMCRP "${PI}"                             2>&1 | tee -a "${LOG}"
# blprev "${PO}"
PI="${PO}" ; PO=sources/pano-10-vignopt.pto     ; sect "set photoopt (vign)"       "PI: ${PI}" "PO: ${PO}" ; pto_var -o "${PO}" --modify-opt --opt Ra,Rb,Rc,Rd,Re,Vb,Vc,Vd,Vx,Vy "${PI}"                 2>&1 | tee -a "${LOG}"
PI="${PO}" ; PO=sources/pano-11-vignopted.pto   ; sect "do photometric opt"        "PI: ${PI}" "PO: ${PO}" ; vig_optimize -o "${PO}" -v -p 5000 "${PI}"                                                  2>&1 | tee -a "${LOG}"
# blprev "${PO}"
PI="${PO}" ; PO=sources/pano-12-modified.pto    ; sect "final modify"              "PI: ${PI}" "PO: ${PO}" ; pano_modify -o "${PO}" --straighten --center --canvas=AUTO $PMFOV $PMCRP "${PI}"   2>&1 | tee -a "${LOG}"

# Final blend
blprev "${PO}"

p=$(pwd)
f=$(basename "${p}")" - ["$(basename "${PO}" ".pto")"].jpg"

sect "Create jpg from last stitch" "ENBLO: \"${ENBLO}\"" "f:     \"${f}\""
convert "${ENBLO}" -quality 100 "${f}" 2>&1 | tee -a "${LOG}"


sect "All done."