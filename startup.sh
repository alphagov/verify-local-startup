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
  set -a
  source urls.env
  set +a
  ./generate/hub-dev-pki.sh
fi

# Generate env files for 12-factored apps
./generate-env.rb -a IDP -f stub-idp.env
./env.sh

bundle check || bundle install
bundle exec ./build.rb ${APPS_YML:-apps.yml}

docker-compose -f ${DOCKER_COMPOSE_FILE:-docker-compose.yml} up -d

echo "$(tput setaf 2)Started - visit $(tput setaf 6)http://localhost:50130/test-rp$(tput setaf 2) to start a journey (may take some time to spin up)$(tput sgr0)"
