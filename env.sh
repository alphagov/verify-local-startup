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
KEY_TYPE=encoded
CERT_TYPE=encoded
TEST_RP_SIGNING_KEY=$($BASE64 data/pki/sample_rp_signing_primary.pk8)
TEST_RP_SIGNING_CERT=$($BASE64 data/pki/sample_rp_signing_primary.crt)
TEST_RP_ENCRYPTION_KEY=$($BASE64 data/pki/sample_rp_encryption_primary.pk8)
TEST_RP_ENCRYPTION_CERT=$($BASE64 data/pki/sample_rp_encryption_primary.crt)
TRUSTSTORE_TYPE=encoded
TRUSTSTORE=$($BASE64 data/pki/hub.ts)
TRUSTSTORE_PASSWORD=marshmallow
EOF

#TEST_RP_MSA_SIGNING_KEY=$($BASE64 data/pki/sample_rp_msa_signing_primary.pk8)
#TEST_RP_MSA_SIGNING_CERT=$($BASE64 data/pki/sample_rp_msa_signing_primary.crt)
#TEST_RP_MSA_ENCRYPTION_KEY=$($BASE64 data/pki/sample_rp_msa_encryption_primary.pk8)
#TEST_RP_MSA_ENCRYPTION_CERT=$($BASE64 data/pki/sample_rp_msa_encryption_primary.crt)

cat << EOF > stub-idp.env
KEY_TYPE=encoded
CERT_TYPE=encoded
STUB_IDP_SIGNING_PRIVATE_KEY=$($BASE64 data/pki/stub_idp_signing_primary.pk8)
STUB_IDP_SIGNING_CERT=$($BASE64 data/pki/stub_idp_signing_primary.crt)
STUB_COUNTRY_SIGNING_PRIVATE_KEY=$($BASE64 data/pki/stub_idp_signing_primary.pk8)
STUB_COUNTRY_SIGNING_CERT=$($BASE64 data/pki/stub_idp_signing_primary.crt)
TRUSTSTORE_TYPE=encoded
METADATA_TRUSTSTORE=$($BASE64 data/pki/metadata.ts)
TRUSTSTORE_PASSWORD=marshmallow
EOF
