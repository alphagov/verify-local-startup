#!/usr/bin/env bash

services=${@:-"config stub-event-sink policy saml-engine saml-proxy saml-soap-proxy verify-matching-service-adapter test-rp stub-idp ida-frontend frontend verify-service-provider-*"}

for service in $services; do
  pkill -9 -f "${service}.jar"
done

pkill -9 verify_metadata_server
pkill -9 ./vsp-startup.sh
pkill -9 -f ocsp_responses
pkill -9 -f bin/ocsp_responder

exit 0

