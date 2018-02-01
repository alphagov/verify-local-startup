#!/bin/bash
set -o errexit

function createInterCa {
  local name=$1
  local commonName=$2

  echo -n "$(tput setaf 3)createInterCa $name $commonName $(tput sgr0) ... "
  sed "s/\$COMMON_NAME/$commonName/" $CSR_TEMPLATE |

  cfssl gencert -config $CFSSL_CONFIG -profile intermediate -ca ./dev-root-ca.pem -ca-key ./dev-root-ca-key.pem /dev/stdin \
    | cfssljson -bare $name

  test 0 -eq $? && echo "$(tput setaf 2)DONE$(tput sgr0)" || echo "$(tput setaf 1)FAILED$(tput sgr0)"
}

function createLeaf {
  local name=$1
  local ca=$2
  local profile=$3
  local commonName=$4

  echo -n "$(tput setaf 3)createLeaf $name $ca $profile $commonName $(tput sgr0) ... "
  sed "s/\$COMMON_NAME/$commonName/" $CSR_TEMPLATE |

  cfssl gencert -config $CFSSL_CONFIG -profile $profile -ca $CA_CERTS_DIR/$ca.pem.test -ca-key $CA_CERTS_DIR/$ca-key.pem.test /dev/stdin \
    | cfssljson -bare $name

  test 0 -eq $? && echo "$(tput setaf 2)DONE$(tput sgr0)" || echo "$(tput setaf 1)FAILED$(tput sgr0)"
}

# Ensure that cfssl and its related tools are on the PATH
PATH=$PATH:$GOPATH/bin/

# Directories we create
CA_CERTS_DIR="$PWD/ca-certificates"
DEV_KEYS_DIR="$PWD/pki"

# Recreate the directory structure
mkdir -p $CA_CERTS_DIR $DEV_KEYS_DIR

# Create the CA certs
pushd $CA_CERTS_DIR >/dev/null
  echo -n "$(tput setaf 3)Initialising Dev Root CA $(tput sgr0) ... "
  sed 's/$COMMON_NAME/Dev Root CA/' $CSR_TEMPLATE | cfssl genkey -initca /dev/stdin | cfssljson -bare dev-root-ca
  test 0 -eq $? && echo "$(tput setaf 2)DONE$(tput sgr0)" || echo "$(tput setaf 1)FAILED$(tput sgr0)"

  createInterCa dev-hub-ca 'Dev Hub CA'
  createInterCa dev-idp-ca 'Dev IDP CA'
  createInterCa dev-rp-ca 'Dev RP CA'
  createInterCa dev-metadata-ca 'Dev Metadata CA'

  # Add .test to all of the generated pems (to match the old file names)
  for file in *.pem; do mv $file $file.test; done
popd >/dev/null

# Generate leaf certs and keys
pushd $DEV_KEYS_DIR >/dev/null
  rm -f ocsp_responses

  createLeaf metadata_signing_a                 dev-metadata-ca  signing       'Dev Metadata Signing A'
  createLeaf metadata_signing_b                 dev-metadata-ca  signing       'Dev Metadata Signing B'
  createLeaf hub_signing_primary                dev-hub-ca       signing       'Dev Hub Signing'
  createLeaf hub_encryption_primary             dev-hub-ca       encipherment  'Dev Hub Encryption'
  createLeaf sample_rp_encryption_primary       dev-rp-ca        encipherment  'Dev Sample RP Encryption'
  createLeaf sample_rp_msa_encryption_primary   dev-rp-ca        encipherment  'Dev Sample RP MSA Encryption'
  createLeaf sample_rp_msa_signing_primary      dev-rp-ca        signing       'Dev Sample RP MSA Signing'
  createLeaf sample_rp_signing_primary          dev-rp-ca        signing       'Dev Sample RP Signing'
  createLeaf stub_idp_signing_primary           dev-idp-ca       signing       'Dev Stub IDP Signing'
  createLeaf hub_signing_secondary              dev-hub-ca       signing       'Dev Hub Signing 2'
  createLeaf hub_encryption_secondary           dev-hub-ca       encipherment  'Dev Hub Encryption 2'
  createLeaf sample_rp_encryption_secondary     dev-rp-ca        encipherment  'Dev Sample RP Encryption 2'
  createLeaf sample_rp_msa_encryption_secondary dev-rp-ca        encipherment  'Dev Sample RP MSA Encryption 2'
  createLeaf sample_rp_msa_signing_secondary    dev-rp-ca        signing       'Dev Sample RP MSA Signing 2'
  createLeaf sample_rp_signing_secondary        dev-rp-ca        signing       'Dev Sample RP Signing 2'
  createLeaf stub_idp_signing_secondary         dev-idp-ca       signing       'Dev Stub IDP Signing 2'

  createLeaf ocsp_responder                     dev-rp-ca        ocsp          'Dev RP OCSP Responder'

  # Generate OCSP responses
  for cert in sample_rp{,_msa}_{encryption,signing}_{primary,secondary}.pem; do
    echo -n "$(tput setaf 3)Generating OCSP response for $cert $(tput sgr0) ... "
    cfssl ocspsign \
      -ca $CA_CERTS_DIR/dev-rp-ca.pem.test \
      -responder ocsp_responder.pem \
      -responder-key ocsp_responder-key.pem \
      -cert $cert \
      | cfssljson -bare -stdout >> ocsp_responses
    test 0 -eq $? && echo "$(tput setaf 2)DONE$(tput sgr0)" || echo "$(tput setaf 1)FAILED$(tput sgr0)"
  done

  # Convert all the keys to .pk8 files
  for file in *-key.pem
  do
    openssl pkcs8 -topk8 -inform PEM -outform DER -in $file -out ${file%-key.pem}.pk8 -nocrypt
  done

  # Remove the files we no longer need
  rm *.csr *-key.pem

  # Rename the pem files to .crt (to match old file names)
  for file in *.pem; do mv $file ${file%.pem}.crt; done
popd >/dev/null

# Remove the files we no longer need
rm "$CA_CERTS_DIR/"*.csr "$CA_CERTS_DIR/"*-key.pem.test

