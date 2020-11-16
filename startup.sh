#!/usr/bin/env bash

show_help() {
  cat << EOF
Usage:
    -y, --yaml-file         Yaml file with a List of repos to build
    -t, --threads           Specifies the number of threads to use to do the
                            the build.  If no number given will generate as many
                            threads as repos.  Suggested 4 threads
    -h, --help              Show's this help message
EOF
}

THREADS=0
YAML_FILE=repos.yml

while [ "$1" != "" ]; do
    case $1 in
        -y | --yaml-file)       shift
                                YAML_FILE=$1
                                ;;
        -t | --threads)         shift
                                THREADS=$1
                                ;;
        -d | --dozzle)          DOZZLE=true
                                ;;
        -h | --help)            show_help
                                exit 0
                                ;;
        * )                     echo -e "Unknown option $1...\n"
                                usage
                                exit 1
    esac
    shift
done

set -eu -o pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

# Build a docker image with all of our dependencies for future steps
if ! command -v docker >/dev/null; then
  >&2 echo "docker: command not found. verify-local-startup requires docker."
  exit 1
fi

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
  bundle exec ./build-local.rb -y $YAML_FILE -t $THREADS
fi

if [[ $DOZZLE == 'true' ]]; then
  echo "Running Dozzle on port 50999"
  docker run --rm --name verify_dozzle_1 --detach --volume=/var/run/docker.sock:/var/run/docker.sock -p 50999:8080 amir20/dozzle
fi

docker-compose -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" --env-file .env up -d
TEST_RP_URL=$(cat config/urls.env | grep TEST_RP_URL | cut -d '=' -f 2)
echo "$(tput setaf 2)Started - visit $(tput setaf 6)${TEST_RP_URL}/test-rp$(tput setaf 2) to start a journey (may take some time to spin up)$(tput sgr0)"
