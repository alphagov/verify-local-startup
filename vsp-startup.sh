#!/usr/bin/env bash

source config/env.sh
rm -rf verify-service-provider-*/
pushd ../verify-service-provider >/dev/null
  ./gradlew clean build distZip
popd >/dev/null
cp ../verify-service-provider/build/distributions/*.zip .

unzip "verify-service-provider-*.zip"

export SAML_SIGNING_KEY="$(base64 data/pki/sample_rp_signing_primary.pk8)"
export SAML_PRIMARY_ENCRYPTION_KEY="$(base64 data/pki/sample_rp_encryption_primary.pk8)"

./verify-service-provider-*/bin/verify-service-provider server configuration/verify-service-provider.yml &
