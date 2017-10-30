#!/usr/bin/env bash
set -e

if [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
    echo "Generates the required environment variables for running verify apps"
    echo "Run ./generate-env.sh > \$app_directory/local.env to configure each app" 
    exit 0
fi

if test ! -d data; then
  command -v cfssl || brew install cfssl
  ./generate/hub-dev-pki.sh
fi

### PORTS
cat config/env.sh

### MSA
cat <<EOF
export HUB_TRUST_STORE=$(base64 data/pki/hub.ts)
export METADATA_TRUST_STORE=$(base64 data/pki/metadata.ts)
export MSA_SIGNING_KEY_PRIMARY=$(base64 data/pki/sample_rp_msa_signing_primary.pk8)
export MSA_SIGNING_CERT_PRIMARY=$(base64 data/pki/sample_rp_msa_signing_primary.crt)
export MSA_SIGNING_KEY_SECONDARY=$(base64 data/pki/sample_rp_msa_signing_secondary.pk8)
export MSA_SIGNING_CERT_SECONDARY=$(base64 data/pki/sample_rp_msa_signing_secondary.crt)
export MSA_ENCRYPTION_KEY_PRIMARY=$(base64 data/pki/sample_rp_msa_encryption_primary.pk8)
export MSA_ENCRYPTION_CERT_PRIMARY=$(base64 data/pki/sample_rp_msa_encryption_primary.crt)
EOF
