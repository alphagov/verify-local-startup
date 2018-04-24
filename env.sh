#!/usr/bin/env bash

BASE64="base64 -w0" # Linux
if [ "$(uname)" = "Darwin" ]; then
    BASE64="base64 -b0" # macOS
fi

cat << EOF > hub.env
HUB_ENCRYPTION_KEY=$($BASE64 data/pki/hub_encryption_primary.pk8)
HUB_ENCRYPTION_CERT=$($BASE64 data/pki/hub_encryption_primary.crt)
HUB_SIGNING_KEY=$($BASE64 data/pki/hub_signing_primary.pk8)
HUB_SIGNING_CERT=$($BASE64 data/pki/hub_signing_primary.crt)
EOF

cat << EOF > test-rp.env
TEST_RP_SIGNING_KEY=$($BASE64 data/pki/sample_rp_signing_primary.pk8)
TEST_RP_SIGNING_CERT=$($BASE64 data/pki/sample_rp_signing_primary.crt)
TEST_RP_ENCRYPTION_KEY=$($BASE64 data/pki/sample_rp_encryption_primary.pk8)
TEST_RP_ENCRYPTION_CERT=$($BASE64 data/pki/sample_rp_encryption_primary.crt)
TEST_RP_MSA_SIGNING_KEY=$($BASE64 data/pki/sample_rp_msa_signing_primary.pk8)
TEST_RP_MSA_SIGNING_CERT=$($BASE64 data/pki/sample_rp_msa_signing_primary.crt)
TEST_RP_MSA_ENCRYPTION_KEY=$($BASE64 data/pki/sample_rp_msa_encryption_primary.pk8)
TEST_RP_MSA_ENCRYPTION_CERT=$($BASE64 data/pki/sample_rp_msa_encryption_primary.crt)
HUB_TRUSTSTORE=$($BASE64 data/pki/hub.ts)
HUB_TRUSTSTORE_PASSWORD=marshmallow
EOF

cat << EOF > stub-idp.env
PORT=80
KEY_TYPE=encoded
STUB_IDP_SIGNING_PRIVATE_KEY=$($BASE64 data/pki/stub_idp_signing_primary.pk8)
CERT_TYPE=encoded
STUB_IDP_SIGNING_CERT=$($BASE64 data/pki/stub_idp_signing_primary.crt)
STUB_IDP_BASIC_AUTH=false
STUB_IDPS_FILE_PATH=/idps/stub-idps.yml
METADATA_ENTITY_ID=https://dev-hub.local
TRUSTSTORE_TYPE=encoded
METADATA_TRUSTSTORE=$($BASE64 data/pki/metadata.ts)
TRUSTSTORE_PASSWORD=marshmallow
STUB_COUNTRY_SIGNING_PRIVATE_KEY=$($BASE64 data/pki/stub_idp_signing_primary.pk8)
STUB_COUNTRY_SIGNING_CERT=$($BASE64 data/pki/stub_idp_signing_primary.crt)
LOG_PATH=/app/logs
EOF
