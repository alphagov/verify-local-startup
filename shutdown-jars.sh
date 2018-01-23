#!/usr/bin/env bash

set -e

tput setaf 5 
cat << 'EOF'
   _____ __          __  __  _                ____                    
  / ___// /_  __  __/ /_/ /_(_)___  ____ _   / __ \____ _      ______ 
  \__ \/ __ \/ / / / __/ __/ / __ \/ __ `/  / / / / __ \ | /| / / __ \
 ___/ / / / / /_/ / /_/ /_/ / / / / /_/ /  / /_/ / /_/ / |/ |/ / / / /
/____/_/ /_/\__,_/\__/\__/_/_/ /_/\__, /  /_____/\____/|__/|__/_/ /_/ 
                                 /____/   Bye-bye!
                                 ..............with jars
EOF
tput sgr0

services=${@:-"config stub-event-sink policy saml-engine saml-proxy saml-soap-proxy verify-matching-service-adapter test-rp ida-sample-rp stub-idp frontend verify-service-provider-*"}

for service in $services; do
  pkill -9 -f "${service}.jar"
done

pkill -9 verify_metadata_server
pkill -9 ./vsp-startup.sh
pkill -9 -f ocsp_responses
pkill -9 -f bin/ocsp_responder

exit 0

