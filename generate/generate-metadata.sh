#!/usr/bin/env bash

script_dir="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"

sources="metadata"
output="metadata/output"
cadir="$PWD/ca-certificates"
certdir="$PWD/pki"

mkdir -p "$sources/dev-connector"
mkdir -p "$sources/dev/idps"
rm -f "$output/*"

# generate
bundle >/dev/null

echo "$(tput setaf 3)Generating metadata sources$(tput sgr0)"
$script_dir/metadata-sources.rb \
  "$certdir"/hub_signing_primary.crt \
  "$certdir"/hub_encryption_primary.crt \
  "$certdir"/stub_idp_signing_primary.crt \
  "$sources/dev" || exit 1

echo "$(tput setaf 3)Generating metadata XML$(tput sgr0)"
bundle exec generate_metadata -c "$sources" -e dev -w -o "$output" --valid-until=36500 \
  --hubCA "$cadir"/dev-root-ca.pem.test \
  --hubCA "$cadir"/dev-hub-ca.pem.test \
  --idpCA "$cadir"/dev-root-ca.pem.test \
  --idpCA "$cadir"/dev-idp-ca.pem.test

echo "$(tput setaf 3)Generating connector metadata XML$(tput sgr0)"
bundle exec generate_metadata -c "$sources" -e dev-connector -r -w -o "$output" --valid-until=36500 \
  --hubCA "$cadir"/dev-root-ca.pem.test \
  --hubCA "$cadir"/dev-hub-ca.pem.test \
  --idpCA "$cadir"/dev-root-ca.pem.test \
  --idpCA "$cadir"/dev-idp-ca.pem.test

if test ! -f "$output"/dev/metadata.xml; then
  echo "$(tput setaf 1)Failed to generate metadata$(tput sgr0)"
  exit 1
fi

# sign
if test -z `which xmlsectool`; then
  echo "$(tput setaf 3)Installing xmlsectool$(tput sgr0)"
  brew install xmlsectool
fi

for env in dev dev-connector; do
  echo "$(tput setaf 3)Signing metadata$(tput sgr0)"
  xmlsectool \
    --sign \
    --inFile "$output"/$env/metadata.xml \
    --outFile "$output"/$env/metadata.signed.xml \
    --certificate "$certdir"/metadata_signing_a.crt \
    --key "$certdir"/metadata_signing_a.pk8 \
    --digest SHA-256

  cp metadata/output/$env/metadata.signed.xml metadata/$env.xml
done

echo "$(tput setaf 3)Generating compatible federation config$(tput sgr0)"
$script_dir/fed-config.rb \
  "$certdir"/sample_rp_signing_primary.crt \
  "$certdir"/sample_rp_encryption_primary.crt \
  "$certdir"/sample_rp_msa_signing_primary.crt \
  "$certdir"/sample_rp_msa_encryption_primary.crt \
  stub-fed-config \
  display-locales
