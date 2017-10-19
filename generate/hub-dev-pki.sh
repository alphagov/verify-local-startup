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
data_dir="$script_dir/../data"

mkdir -p "$data_dir"

pushd "$data_dir" >/dev/null
  rm -rf {pki,metadata,stub-fed-config}
  mkdir -p {pki,metadata,stub-fed-config}

  mkdir -p metadata/output/{dev,compliance-tool}
  mkdir -p stub-fed-config

  env \
    CSR_TEMPLATE="$script_dir/template-csr.json" \
    CFSSL_CONFIG="$script_dir/cfssl-config.json" \
    $script_dir/generate-certs.sh

  $script_dir/generate-truststores.sh
  $script_dir/generate-metadata.sh
popd >/dev/null
