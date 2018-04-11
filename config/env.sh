#!/usr/bin/env bash

script_location=$(dirname "${BASH_SOURCE[0]}")
ports_file="$script_location/ports.env"
vls_type=${VLS_TYPE:-}

set -o allexport
source $ports_file
set +o allexport
if [ "$vls_type" = "localhost" ]; then
    export TEST_RP_MSA_URI=http://localhost:${TEST_RP_MSA_PORT}
    export VSP_MSA_URI=http://localhost:${VSP_MSA_PORT}
else
    export TEST_RP_MSA_URI=http://msa
    export VSP_MSA_URI=http://vspmsa
fi
