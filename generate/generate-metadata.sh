#!/usr/bin/env bash

script_dir="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"

sources="metadata"
output="metadata/output"
cadir="$PWD/ca-certificates"
certdir="$PWD/pki"

mkdir -p "$sources/dev/idps"
mkdir -p "$sources/compliance-tool/idps"
rm -f "$output/*"

# generate
bundle >/dev/null

echo "$(tput setaf 3)Generating metadata sources$(tput sgr0)"
$script_dir/metadata-sources.rb \
  "$certdir"/hub_signing_primary.crt \
  "$certdir"/hub_encryption_primary.crt \
  "$certdir"/stub_idp_signing_primary.crt \
  "$sources/dev" || exit 1

env FRONTEND_URL="http://localhost:${COMPLIANCE_TOOL_PORT}" \
  $script_dir/metadata-sources.rb \
  "$certdir"/hub_signing_primary.crt \
  "$certdir"/hub_encryption_primary.crt \
  "$certdir"/stub_idp_signing_primary.crt \
  "$sources/compliance-tool" || exit 1

echo "$(tput setaf 3)Generating metadata XML$(tput sgr0)"
bundle exec generate_metadata -c "$sources" -e dev -w -o "$output" --valid-until=36500 \
  --hubCA "$cadir"/dev-root-ca.pem.test \
  --hubCA "$cadir"/dev-hub-ca.pem.test \
  --idpCA "$cadir"/dev-root-ca.pem.test \
  --idpCA "$cadir"/dev-idp-ca.pem.test

for src in dev compliance-tool; do
  bundle exec generate_metadata -c "$sources" -e $src -w -o "$output" --valid-until=36500 \
    --hubCA "$cadir"/dev-root-ca.pem.test \
    --hubCA "$cadir"/dev-hub-ca.pem.test \
    --idpCA "$cadir"/dev-root-ca.pem.test \
    --idpCA "$cadir"/dev-idp-ca.pem.test
  
  if test ! -f "$output"/$src/metadata.xml; then
    echo "$(tput setaf 1)Failed to generate metadata$(tput sgr0)"
    exit 1
  fi
  
  # sign
  XMLSECTOOL="xmlsectool"
  if test -z `which xmlsectool`; then
      if [ "$(uname)" == "Darwin" ]; then
          echo "$(tput setaf 3)Detected macOS - installing xmlsectool via brew$(tput sgr0)"
          brew install xmlsectool
      else
          echo "$(tput setaf 3)Detected a host OS that is not macOS - installing xmlsectool manually$(tput sgr0)"
          if [ ! -f xmlsectool-2.0.0-bin.zip ]; then
              set -e
              curl -o xmlsectool-2.0.0-bin.zip http://shibboleth.net/downloads/tools/xmlsectool/latest/xmlsectool-2.0.0-bin.zip >/dev/null 2>/dev/null
              echo "9169b27479d9d8c4fcbf31434cb1567c  xmlsectool-2.0.0-bin.zip" > xmlsectool-2.0.0-bin.zip.md5
              md5sum -c xmlsectool-2.0.0-bin.zip.md5
              unzip -n xmlsectool-2.0.0-bin.zip >/dev/null 2>/dev/null
          fi
          XMLSECTOOL="xmlsectool-2.0.0/xmlsectool.sh"
      fi
  fi
  
  echo "$(tput setaf 3)Signing metadata$(tput sgr0)"
  $XMLSECTOOL \
    --sign \
    --inFile "$output"/$src/metadata.xml \
    --outFile "$output"/$src/metadata.signed.xml \
    --certificate "$certdir"/metadata_signing_a.crt \
    --key "$certdir"/metadata_signing_a.pk8 \
    --digest SHA-256

  cp metadata/output/$src/metadata.signed.xml metadata/$src.xml
done

echo "$(tput setaf 3)Generating compatible federation config$(tput sgr0)"
$script_dir/fed-config.rb \
  "$certdir"/sample_rp_signing_primary.crt \
  "$certdir"/sample_rp_encryption_primary.crt \
  "$certdir"/sample_rp_msa_signing_primary.crt \
  "$certdir"/sample_rp_msa_encryption_primary.crt \
  stub-fed-config
