#!/usr/bin/env bash

cat << EOF > hub.env
HUB_ENCRYPTION_KEY=$(base64 data/pki/hub_encryption_primary.pk8)
HUB_ENCRYPTION_CERT=$(base64 data/pki/hub_encryption_primary.crt)
HUB_SIGNING_KEY=$(base64 data/pki/hub_signing_primary.pk8)
HUB_SIGNING_CERT=$(base64 data/pki/hub_signing_primary.crt)
EOF

cat << EOF > test-rp.env
TEST_RP_SIGNING_KEY=$(base64 data/pki/sample_rp_signing_primary.pk8)
TEST_RP_SIGNING_CERT=$(base64 data/pki/sample_rp_signing_primary.crt)
TEST_RP_ENCRYPTION_KEY=$(base64 data/pki/sample_rp_encryption_primary.pk8)
TEST_RP_ENCRYPTION_CERT=$(base64 data/pki/sample_rp_encryption_primary.crt)
TEST_RP_MSA_SIGNING_KEY=$(base64 data/pki/sample_rp_msa_signing_primary.pk8)
TEST_RP_MSA_SIGNING_CERT=$(base64 data/pki/sample_rp_msa_signing_primary.crt)
TEST_RP_MSA_ENCRYPTION_KEY=$(base64 data/pki/sample_rp_msa_encryption_primary.pk8)
TEST_RP_MSA_ENCRYPTION_CERT=$(base64 data/pki/sample_rp_msa_encryption_primary.crt)
HUB_TRUSTSTORE=$(base64 data/pki/hub.ts)
HUB_TRUSTSTORE_PASSWORD=marshmallow
EOF
