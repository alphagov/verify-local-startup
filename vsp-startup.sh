#!/usr/bin/env bash

source lib/services.sh
source config/env.sh

rm -rf verify-service-provider-*/

pushd ../verify-service-provider >/dev/null
  ./gradlew clean build distZip
popd >/dev/null
cp ../verify-service-provider/build/distributions/*.zip .

unzip "verify-service-provider-*.zip"

cp ../verify-service-provider/local-running/local-config.yml verify-service-provider-local-config.yml

export SAML_SIGNING_KEY="$(base64 data/pki/sample_rp_signing_primary.pk8)"
export SAML_PRIMARY_ENCRYPTION_KEY="$(base64 data/pki/sample_rp_encryption_primary.pk8)"
export SERVICE_ENTITY_IDS='["http://dev-rp.local/SAML2/MD"]'
export METADATA_TRUST_STORE="$(base64 data/pki/metadata.ts)"

./verify-service-provider-*/bin/verify-service-provider server verify-service-provider-local-config.yml &

pid=$!

start_service_checker "verify-service-provider" $VSP_PORT $pid "logs/verify-service-provider.log" "localhost:$VSP_PORT" >/dev/tty
