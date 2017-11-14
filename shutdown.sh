#!/usr/bin/env bash

services=${@:-"config stub-event-sink policy saml-engine saml-proxy saml-soap-proxy verify-matching-service-adapter test-rp stub-idp ida-frontend verify-service-provider-*"}

for service in $services; do
  pkill -9 -f "${service}.jar"
done

exit 0

