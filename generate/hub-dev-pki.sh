#!/usr/bin/env bash

set -o errexit

tput setaf 5
cat <<EOF
 ____                   ____               ____  _  _____ 
|  _ \ _ __ ___ _ __   |  _ \  _____   __ |  _ \| |/ /_ _|
| |_) | '__/ _ \ '_ \  | | | |/ _ \ \ / / | |_) | ' / | | 
|  __/| | |  __/ |_) | | |_| |  __/\ V /  |  __/| . \ | | 
|_|   |_|  \___| .__/  |____/ \___| \_/   |_|   |_|\_\___|
               |_|                                        
EOF
tput sgr0

unset_message="should be set to the runtime location (for metadata/fed config setting)"
quit() {
  echo $1
  exit 1
}
test -z $HUB_CONNECTOR_ENTITY_ID && quit "HUB_CONNECTOR_ENTITY_ID $unset_message"
test -z $FRONTEND_URL && quit "FRONTEND_URL $unset_message"
test -z $STUB_IDP_URL && quit "STUB_IDP_URL $unset_message"
test -z $TEST_RP_URL && quit "TEST_RP_URL $unset_message"
test -z $MSA_URL && quit "MSA_URL $unset_message"
test -z $COUNTRY_METADATA_URI && quit "COUNTRY_METADATA_URI $unset_message"

script_dir="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
source "$script_dir"/../config/env.sh
data_dir="$script_dir/../data"

mkdir -p "$data_dir"

pushd "$data_dir" >/dev/null
  rm -rf {pki,metadata,stub-fed-config}
  mkdir -p {pki,metadata,stub-fed-config}

  mkdir -p metadata/output/{dev,dev-connector}
  mkdir -p stub-fed-config

  env \
    CSR_TEMPLATE="$script_dir/template-csr.json" \
    CFSSL_CONFIG="$script_dir/cfssl-config.json" \
    $script_dir/generate-certs.sh

  $script_dir/generate-truststores.sh
  $script_dir/generate-metadata.sh
  $script_dir/generate-trust-anchor.sh
popd >/dev/null
