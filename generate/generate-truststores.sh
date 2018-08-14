#!/usr/bin/env bash

set -o errexit

createTruststore () {
  local store="$1"
  local pass="marshmallow"

  shift 1
  local certs="$@"
  
  for name in $certs; do
    cert="$PWD/ca-certificates/${name}.crt"
    echo "$(tput setaf 3)Adding certificate $name to $store truststore$(tput sgr0)"
    keytool -import -noprompt -alias "$name" -file "$cert" -keystore "pki/${store}.ts" -storepass "$pass" >/dev/null
  done
}

mkdir -p pki
rm -f pki/*.ts

createTruststore hub                verify-root verify-hub verify-idp
createTruststore hub_federation     verify-root verify-hub
createTruststore idp_federation     verify-root verify-idp
createTruststore relying_parties    verify-root verify-rp
createTruststore metadata           verify-root verify-metadata
