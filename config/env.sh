#!/usr/bin/env bash

script_location=$(dirname "${BASH_SOURCE[0]}")
ports_file="$script_location/ports.env"

set -o allexport
source $ports_file
set +o allexport
if [ "$VLS_TYPE" = "localhost" ]; then
    export MSA_URI=http://localhost:${TEST_RP_MSA_PORT}
else
    export MSA_URI=http://msa
fi

