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

script_dir="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"

mkdir -p data

pushd data >/dev/null
  rm -rf {pki,metadata,stub-fed-config}
  mkdir -p {pki,metadata,stub-fed-config}

  mkdir -p dev-pki/main/resources/{ca-certificates,dev-keys}
  mkdir -p metadata/output/dev
  mkdir -p stub-fed-config

  env \
    CSR_TEMPLATE="$script_dir/template-csr.json" \
    CFSSL_CONFIG="$script_dir/cfssl-config.json" \
    $script_dir/generate-certs.sh

  $script_dir/generate-truststores.sh
  $script_dir/generate-metadata.sh

  cp dev-pki/main/resources/dev-keys/hub_{signing,encryption}_{primary,secondary}.{crt,pk8} pki/
  cp dev-pki/main/resources/dev-keys/ocsp_responses pki/
  cp metadata/output/dev/metadata.signed.xml metadata/metadata.xml
popd >/dev/null
