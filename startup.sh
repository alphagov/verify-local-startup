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
EOF
tput sgr0

# Generate PKI and config if necessary
data_version="$(./generate/get-version.sh)"
if test ! -d data -o ! "$(cat data/.version 2>/dev/null)" == $data_version; then
  command -v cfssl >/dev/null || brew install cfssl
  ./generate/hub-dev-pki.sh
fi

./env.sh

bundle check || bundle install
bundle exec ./build.rb ${APPS_YML:-apps.yml}

docker-compose -f ${DOCKER_COMPOSE_FILE:-docker-compose.yml} up -d

echo "$(tput setaf 2)Started - visit $(tput setaf 6)http://localhost:50130/test-rp$(tput setaf 2) to start a journey (may take some time to spin up)$(tput sgr0)"
