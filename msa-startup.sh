#!/usr/bin/env bash
set -u

source lib/services.sh

mkdir -p logs
if test ! -d data; then
  command -v cfssl || brew install cfssl
  ./generate/hub-dev-pki.sh
fi
pkill verify_metadata_server
( bin/metadata_server > logs/metadata_server.log 2>&1 & )

build_service ../ida-msa

pids=`ps aux | grep java | grep ida-msa.yml | awk '{print $2}'`
for pid in $pids; do
  kill $pid
done

cp data/pki/identity_providers.ts ../ida-msa
cp data/pki/metadata.ts ../ida-msa
extra_java_args="-Ddw.signingKeys.primary.privateKey.key=$(base64 data/pki/sample_rp_msa_signing_primary.pk8) \
    -Ddw.signingKeys.primary.publicKey.cert=$(base64 data/pki/sample_rp_msa_signing_primary.crt) \
    -Ddw.encryptionKeys[0].privateKey.key=$(base64 data/pki/sample_rp_msa_encryption_primary.pk8) \
    -Ddw.encryptionKeys[0].publicKey.cert=$(base64 data/pki/sample_rp_msa_encryption_primary.crt) \
    -Ddw.hub.trustStore.path=identity_providers.ts \
    -Ddw.metadata.trustStore.path=metadata.ts"

pushd ../ida-msa > /dev/null
mkdir -p logs
start_service ida-msa-local . configuration/ida-msa.yml 50210 $extra_java_args
popd > /dev/null
wait