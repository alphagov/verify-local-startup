#!/usr/bin/env bash

set -e

tput setaf 4
cat << 'EOF'
__     __        _  __         _   _       _        ____  ___  
\ \   / /__ _ __(_)/ _|_   _  | | | |_   _| |__    / ___|/ _ \ 
 \ \ / / _ \ '__| | |_| | | | | |_| | | | | '_ \  | |  _| | | |
  \ V /  __/ |  | |  _| |_| | |  _  | |_| | |_) | | |_| | |_| |
   \_/ \___|_|  |_|_|  \__, | |_| |_|\__,_|_.__/   \____|\___/
                       |___/
                       ...................with jars
EOF
tput sgr0

export VLS_TYPE="localhost"

source lib/services.sh
source config/env.sh

# Generate PKI and config if necessary
if test ! -d data; then
  command -v cfssl >/dev/null || brew install cfssl
  ./generate/hub-dev-pki.sh
fi

./env.sh

mkdir -p logs

( bin/metadata_server >logs/metadata_server.log 2>&1 & )
( bin/ocsp_responder >logs/ocsp_responder.log 2>&1 & )

build_service ../verify-hub
build_service ../verify-test-rp
build_service ../verify-stub-idp
build_service ../verify-matching-service-adapter

start_service stub-event-sink ../verify-hub/hub/stub-event-sink configuration/hub/stub-event-sink.yml $EVENT_SINK_PORT
start_service config ../verify-hub/hub/config configuration/hub/config.yml $CONFIG_PORT
start_service policy ../verify-hub/hub/policy configuration/hub/policy.yml $POLICY_PORT
start_service saml-engine ../verify-hub/hub/saml-engine configuration/hub/saml-engine.yml $SAML_ENGINE_PORT
start_service saml-proxy ../verify-hub/hub/saml-proxy configuration/hub/saml-proxy.yml $SAML_PROXY_PORT
start_service saml-soap-proxy ../verify-hub/hub/saml-soap-proxy configuration/hub/saml-soap-proxy.yml $SAML_SOAP_PROXY_PORT
start_service stub-idp ../verify-stub-idp configuration/stub-idp.yml $STUB_IDP_PORT
start_service test-rp ../verify-test-rp configuration/test-rp.yml $TEST_RP_PORT
start_service test-rp-msa ../verify-matching-service-adapter configuration/test-rp-msa.yml $TEST_RP_MSA_PORT
start_service vsp-msa ../verify-matching-service-adapter configuration/vsp-msa.yml $VSP_MSA_PORT

pushd ../verify-frontend >/dev/null
  ./startup.sh
popd >/dev/null

wait
echo "$(tput setaf 2)Started - visit $(tput setaf 6)http://localhost:50130/test-rp$(tput setaf 2) to start a journey (may take some time to spin up)$(tput sgr0)"
