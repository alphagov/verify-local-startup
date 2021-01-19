#!/usr/bin/env bash

rebuild_data() {
  # Check if our test file exists before we try to do anything
  if [ ! -f ./data/pki/hub.ts ]; then
    return 0
  fi

  if groups | grep $(/usr/bin/stat -c %G data) > /dev/null; then
    echo "Removing data directory for rebuild..."
    if [ -d data ]; then
      rm -r data
    fi
  else
    while true; do
    read -p "Unable to remove data directory, use sudo? [y/n] " p
    case $p in
        y|Y|yes)  if [ -d data ]; then
                    sudo rm -r data
                  fi
                  break
                  ;;
        n|N|no)   echo "Unable to remove data directory."
                  break
                  ;;
    esac
    done
    echo "Unable to remove data directory."
  fi
}

check_data_age() {
  # Check if our test file exists before we try to do anything
  if [ ! -f ./data/pki/hub.ts ]; then
    return 0
  fi

  DATA_DIR_AGE=$(/usr/bin/stat -c %Y data/pki/hub.ts)
  let "MAX_AGE = 1209600 + $DATA_DIR_AGE"
  NOW=$(date +%s)
  if [[ $NOW > $MAX_AGE ]]; then
    echo "Data directory has expired... Rebuilding"
    rebuild_data
  else
    echo "Data directory is still good."
  fi
}

show_help() {
  cat << EOF
Usage:
    -y, --yaml-file         Yaml file with a List of repos to build
    -t, --threads           Specifies the number of threads to use to do the
                            the build.  If no number given will generate as many
                            threads as repos.  Suggested 4 threads
    -r, --retry-build       Sometimes the build can fail due to resourcing issues
                            by default we'll retry once.  If you want to retry
                            more times set a number here or set it to 0 to not retry.
    -w, write-build-log     Writes the build log even for successful builds
    -s, --skip-data-check   Skip checking the age of the data directory
    -g, --group             Set the group owner of the data directory
                            Default is to use docker.
    -R, --rebuild-data      Tells the script to remove and rebuild the data directory
    -d, --dozzle            Run Dozzle for docker output viewing on port 50999
    -h, --help              Show's this help message
EOF
}

GROUP=docker
GROUP_LINE="docker:x:997:"
REBUILD_DATA=false
SKIP_DATA_CHECK=false
THREADS=0
RETRIES=1
YAML_FILE=repos.yml
DOZZLE=false
DOZZLEPORT=50999
WRITE_BUILD_LOG=''

while [ "$1" != "" ]; do
    case $1 in
        -y | --yaml-file)       shift
                                YAML_FILE=$1
                                ;;
        -t | --threads)         shift
                                THREADS=$1
                                ;;
        -r | --retry-build)     shift
                                RETRIES=$1
                                ;;
        -w | --write-build-log) WRITE_BUILD_LOG='-w'
                                ;;
        -d | --dozzle)          DOZZLE=true
                                ;;
        -p | --dozzleport)      shift
                                DOZZLEPORT=$1
                                ;;
        -g | --group)           shift
                                GROUP=$1
                                if cat /etc/group | grep $GROUP | cut -d ':' -f 1 > /dev/null; then
                                  GROUP_LINE="$GROUP:x:$(cat /etc/group | grep $GROUP: | cut -d ':' -f 3):"
                                else
                                  echo "No such group in your group file"
                                  exit 1
                                fi
                                ;;
        -R | --rebuild-data)    REBUILD_DATA=true
                                ;;
        -s | --skip-data-check) SKIP_DATA_CHECK=true
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

if which rbenv > /dev/null; then
  if ! rbenv versions |grep 2.7.2 > /dev/null; then
    echo "Using rbenv to install ruby 2.7.2..."
    rbenv install
  fi
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

# Options for rebuilding the data directory
if [[ $SKIP_DATA_CHECK == "false" ]]; then
  check_data_age
fi

if [[ $REBUILD_DATA == "true" ]]; then
  rebuild_data
fi

# Running generate scripts in docker avoids having to install their
# dependencies on the host.
docker build -t verify-local-startup --build-arg DATA_GROUP=$GROUP --build-arg GROUP_LINE=$GROUP_LINE .

# Inlining the following block of commands to docker run rather than putting
# them in their own script to avoid an extra level of bash indirection
docker run -t -v "$script_dir:/verify-local-startup/" verify-local-startup '
set -e
if ! test -d data; then
  generate/hub-dev-pki.sh
  chown -R root:$DATA_GROUP data
  chmod -R g+w data
fi
./env.sh
'

if test ! "${1:-}" == "skip-build"; then
  bundle check || bundle install
  bundle exec ./build-local.rb -r $RETRIES -y $YAML_FILE -t $THREADS $WRITE_BUILD_LOG
fi

if [[ $DOZZLE == 'true' ]]; then
  echo "Running Dozzle on port $DOZZLEPORT"
  if ! docker ps |grep doz > /dev/null; then
    docker run --rm --name verify_dozzle_1 --detach --volume=/var/run/docker.sock:/var/run/docker.sock -p $DOZZLEPORT:8080 amir20/dozzle
  fi
  echo "Dozzle is running and can be found at http://localhost:$DOZZLEPORT/"
fi

docker-compose -f "${DOCKER_COMPOSE_FILE:-docker-compose.yml}" --env-file .env up -d
TEST_RP_URL=$(cat config/urls.env | grep TEST_RP_URL | cut -d '=' -f 2)
echo "$(tput setaf 2)Started - visit $(tput setaf 6)${TEST_RP_URL}/test-rp$(tput setaf 2) to start a journey (may take some time to spin up)$(tput sgr0)"
