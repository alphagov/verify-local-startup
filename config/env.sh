#!/usr/bin/env bash

script_location=$(dirname "${BASH_SOURCE[0]}")
ports_file="$script_location/ports.env"
urls_file="$script_location/urls.env"
vls_type=${VLS_TYPE:-}

set -o allexport
source $ports_file
set +o allexport
if [ "$vls_type" = "localhost" ]; then
    export MSA_URI=http://localhost:${TEST_RP_MSA_PORT}
else
    export MSA_URI=http://msa
fi
export FRONTEND_URL=$(cat $urls_file |grep FRONTEND_URL |cut -d '=' -f2)
export STUB_IDP_URL=$(cat $urls_file |grep STUB_IDP_URL |cut -d '=' -f2)
export MSA_URL=$(cat $urls_file |grep MSA_URL |cut -d '=' -f2)
export TEST_RP_URL=$(cat $urls_file |grep TEST_RP_URL |cut -d '=' -f2)