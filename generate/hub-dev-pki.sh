#!/usr/bin/env bash

####
# Start here for generate-metadata and generate-truststores scripts
####

####
# Requirements checking
####
if test ! `which ruby`; then
    echo "You need to install Ruby... exiting."
    exit 1
fi
if test ! `which java`; then
    echo "You need to install Java... exiting."
    exit 1
fi
if test ! `which cfssl`; then
    echo "You need to install cfssl before you can run this script... exiting."
    exit 1
fi

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
source "$script_dir"/../config/env.sh
data_dir="$script_dir/../data"

mkdir -p "$data_dir"

pushd "$data_dir" >/dev/null
  rm -rf {pki,metadata,stub-fed-config}
  mkdir -p {pki,metadata,stub-fed-config,ca-certificates}

  mkdir -p metadata/output/{dev,compliance-tool}
  mkdir -p stub-fed-config

  $script_dir/pki.rb

  # Temporary shim to fit with old scripts
  mv $data_dir/pki/verify-*.crt $data_dir/ca-certificates

  $script_dir/generate-truststores.sh
  $script_dir/generate-metadata.sh
popd >/dev/null
