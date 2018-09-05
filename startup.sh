#!/usr/bin/env bash

set -eu -o pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

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

# Build a docker image with all of our dependencies for future steps
if ! command -v docker >/dev/null; then
  >&2 echo "docker: command not found. verify-local-startup requires docker."
  exit 1
fi

# Running generate scripts in docker avoids having to install their
# dependencies on the host.
docker build -t verify-local-startup .

# Inlining the following block of commands to docker run rather than putting
# them in their own script to avoid an extra level of bash indirection
docker run -t -v "$script_dir:/verify-local-startup/" verify-local-startup '
set -e
if ! test -d data; then
  generate/hub-dev-pki.sh
fi
./env.sh
'

if test ! "${1:-}" == "skip-build"; then
  bundle check || bundle install
  bundle exec ./build-local.rb repos.yml
fi

docker-compose -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" up -d

echo "$(tput setaf 2)Started - visit $(tput setaf 6)http://test-rp/test-rp$(tput setaf 2) to start a journey after starting the SOCKS proxy (may take some time to spin up)$(tput sgr0)"
