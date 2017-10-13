#!/usr/bin/env bash

set -o errexit

createTruststore () {
  local store="$1"
  local pass="marshmallow"

  shift 1
  local certs="$@"
  
  for name in $certs; do
    cert="$PWD/dev-pki/main/resources/ca-certificates/${name}.pem.test"
    echo "$(tput setaf 3)Adding certificate $name to $store truststore$(tput sgr0)"
    keytool -import -noprompt -alias "$name" -file "$cert" -keystore "pki/${store}.ts" -storepass "$pass" >/dev/null
  done
}

mkdir -p pki
rm -f pki/*.ts

createTruststore identity_providers dev-root-ca dev-idp-ca
createTruststore relying_parties    dev-root-ca dev-rp-ca
createTruststore metadata           dev-root-ca dev-metadata-ca
