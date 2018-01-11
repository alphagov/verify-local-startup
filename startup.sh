#!/usr/bin/env bash

tput setaf 4
cat << 'EOF'
__     __        _  __         _   _       _        ____  ___  
\ \   / /__ _ __(_)/ _|_   _  | | | |_   _| |__    / ___|/ _ \ 
 \ \ / / _ \ '__| | |_| | | | | |_| | | | | '_ \  | |  _| | | |
  \ V /  __/ |  | |  _| |_| | |  _  | |_| | |_) | | |_| | |_| |
   \_/ \___|_|  |_|_|  \__, | |_| |_|\__,_|_.__/   \____|\___/ 
                       |___/                                   
EOF
tput sgr0

# Generate PKI and config if necessary
if test ! -d data; then
  command -v cfssl >/dev/null || brew install cfssl
  ./generate/hub-dev-pki.sh
fi

if test ! "$1" = "skip-build"; then
  for repo in ida-sample-rp ida-stub-idp verify-matching-service-adapter; do
    echo -n "Building in $(tput setaf 3)$repo$(tput sgr0)... "
    pushd "../$repo" >/dev/null
      if ./gradlew --parallel clean distZip -Pversion=local -x test > build-output.log 2>&1; then
        echo "$(tput setaf 2)done$(tput sgr0)"
      else
        echo "$(tput setaf 1)failed$(tput sgr0) - see build-output.log"
      fi
    popd >/dev/null
  done
  # Hub uses modules so we need to explicitly distZip each app
  echo "Building in $(tput setaf 3)verify-hub$(tput sgr0)"
  pushd ../verify-hub >/dev/null
    for app in config policy saml-engine saml-proxy saml-soap-proxy stub-event-sink; do
      echo -n "Building $(tput setaf 3)$app$(tput sgr0)... "
      if ./gradlew --parallel :hub:$app:clean :hub:$app:distZip -Pversion=local -x test > build-output.log 2>&1; then
        echo "$(tput setaf 2)done$(tput sgr0)"
      else
        echo "$(tput setaf 1)failed$(tput sgr0) - see build-output.log"
      fi
    done
  popd >/dev/null
fi

for app in config policy saml-engine saml-proxy saml-soap-proxy stub-event-sink; do
  ln -f ../verify-hub/hub/$app/build/distributions/$app-0.1.local.zip $app.zip
done

for app in ida-sample-rp ida-stub-idp verify-matching-service-adapter; do
  ln -f ../$app/build/distributions/*.zip $app.zip
done

docker-compose up -d

echo "$(tput setaf 2)Started - visit http://localhost:94/test-rp to start a journey (may take some time to spin up)$(tput sgr0)"
