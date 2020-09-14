#!/usr/bin/env bash

script_dir="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"

sources="metadata"
output="metadata/output"
cadir="$PWD/ca-certificates"
certdir="$PWD/pki"
xmlsectool="${XMLSECTOOL:-xmlsectool}"

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
  --hubCA "$cadir"/verify-root.crt \
  --hubCA "$cadir"/verify-hub.crt \
  --idpCA "$cadir"/verify-root.crt \
  --idpCA "$cadir"/verify-idp.crt

for src in dev compliance-tool; do
  bundle exec generate_metadata -c "$sources" -e $src -w -o "$output" --valid-until=36500 \
    --hubCA "$cadir"/verify-root.crt \
    --hubCA "$cadir"/verify-hub.crt \
    --idpCA "$cadir"/verify-root.crt \
    --idpCA "$cadir"/verify-idp.crt
  
  if test ! -f "$output"/$src/metadata.xml; then
    echo "$(tput setaf 1)Failed to generate metadata$(tput sgr0)"
    exit 1
  fi
  
  # Setup xmlsectool if not set already
  if [ -z $XMLSECTOOL ]; then
    # Check if we have xmlsectool already
    if `which xmlsectool`; then
        XMLSECTOOL="xmlsectool"
    elif -f "$script_dir/../bin/xmlsectool-2.0.0/xmlsectool.sh"; then
        XMLSECTOOL="$script_dir/../bin/xmlsectool-2.0.0/xmlsectool.sh"
    fi
    
    # If not we'll install it either via homebrew or directly from shibboleth.net
    if test -z XMLSECTOOL ; then
        if test `which brew`; then
            echo "$(tput setaf 3)Installing xmlsectool via Homebrew...$(tput sgr0)"
            brew install xmlsectool
            XMLSECTOOL="xmlsectool"
        else
            echo "$(tput setaf 3)Downloading xmlsectool...$(tput sgr0)"
            if test `which wget`; then
            wget -O /tmp/xmlsectool-2.0.0.zip "http://shibboleth.net/downloads/tools/xmlsectool/latest/xmlsectool-2.0.0-bin.zip"
            elif test `which curl`; then 
            curl --output /tmp/xmlsectool-2.0.0-bin.zip "http://shibboleth.net/downloads/tools/xmlsectool/latest/xmlsectool-2.0.0-bin.zip"
            fi
            if ! -f "/tmp/xmlsectool-2.0.0-bin.zip"; then
                echo "Failed to download xmlsectool... Please make sure you have wget or curl installed."
                exit 1
            fi
            unzip /tmp/xmlsectool-2.0.0.zip -d $script_dir/../bin/xmlsectool-2.0.0
            XMLSECTOOL="$script_dir/../bin/xmlsectool-2.0.0/xmlsectool.sh"
        fi
    fi
  fi

  # Set JAVA_HOME if not set already
  if [ -z $JAVA_HOME ]; then
    export JAVA_HOME=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | cut -d '=' -f 2 | cut -d ' ' -f 2)
  fi

  # sign
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
  stub-fed-config \
  display-locales
