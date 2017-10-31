#!/usr/bin/env bash
set -ue

tput setaf 4
cat << 'EOF'
  _____                ___                     ______          __
 / ___/__  __ _  ___  / (_)__ ____  _______   /_  __/__  ___  / /
/ /__/ _ \/  ' \/ _ \/ / / _ `/ _ \/ __/ -_)   / / / _ \/ _ \/ / 
\___/\___/_/_/_/ .__/_/_/\_,_/_//_/\__/\__/   /_/  \___/\___/_/  
              /_/                                                
EOF
tput sgr0

source lib/services.sh
source config/env.sh

export METADATA_URL=http://localhost:${METADATA_PORT}/compliance-tool.xml

# Generate PKI and config if necessary
if test ! -d data; then
  command -v cfssl >/dev/null || brew install cfssl
  ./generate/hub-dev-pki.sh
fi

mkdir -p logs

( bin/metadata_server >logs/metadata_server.log 2>&1 & )
( bin/ocsp_responder >logs/ocsp_responder.log 2>&1 & )

build_service ../verify-matching-service-adapter
build_service ../ida-stub-idp
build_service ../ida-sample-rp
build_service ../ida-compliance-tool

start_service verify-matching-service-adapter ../verify-matching-service-adapter configuration/test-rp-msa.yml $TEST_RP_MSA_PORT
start_service stub-idp ../ida-stub-idp configuration/stub-idp.yml $STUB_IDP_PORT
start_service test-rp ../ida-sample-rp configuration/test-rp.yml $TEST_RP_PORT
start_service compliance-tool ../ida-compliance-tool/compliance-tool configuration/compliance-tool.yml $COMPLIANCE_TOOL_PORT

wait
