#!/usr/bin/env bash

rebuild_data() {
  REMOVE_DATA_DIR="echo \"Removing data directory...\"
rm -r data
rm *.env"
}

check_data_age() {
  # Check if our test file exists before we try to do anything
  if [ ! -d ./data ]; then
    return 0
  fi

  DATA_DIR_AGE=$($STAT data)
  let "MAX_AGE = 1209600 + $DATA_DIR_AGE"
  NOW=$(date +%s)
  if [[ $NOW > $MAX_AGE ]]; then
    echo "Data directory has expired... Rebuilding"
    rebuild_data
  else
    echo "Data directory is still good."
  fi
}

clean_up() {
  docker build -t verify-local-startup .
  docker run -t -v "$script_dir:/verify-local-startup/" verify-local-startup "
if [ -d data ]; then
  rm -r data
fi
if [ -f hub.env ]; then
  rm *.env
fi
logfiles=(logs/*.log)
if [ \${#logfiles[@]} -gt 0 ]; then
  rm logs/*.log
fi
"
  echo "Verify local startup has been cleaned up."
  exit 0
}

show_help() {
  cat << EOF
Usage:

  Options:
    -y, --yaml-file <file>      Yaml file with a List of repos to build.
                                Default ./repos.yml
    -t, --threads <number>      Specifies the number of threads to use to do the
                                the build.  If no number given will generate as many
                                threads as repos.  Suggested 4 threads.
                                On macs the default is 2 on other systems 0.
    -r, --retry-build <number>  Sometimes the build can fail due to resourcing issues
                                by default we'll retry once.  If you want to retry
                                more times set a number here or set it to 0 to not retry.

  Switches:
    -w, --write-build-log       Writes the build log even for successful builds
    -s, --skip-data-check       Skip checking the age of the data directory
    -b, --skip-build            Allows you to skip the build process.  Useful if you've
                                already built everything and your developing something.
    -R, --rebuild-data          Tells the script to remove and rebuild the data directory.
    -i, --include-maven-local   Copy your local maven directory to the Docker images. Allows
                                you to use SNAPSHOTs of our libraries in the build.
    
  Dozzle (useful on Linux):
    -d, --dozzle                Run Dozzle for docker output viewing on port 50999.
    -p, --dozzleport <number>   Sets the port doozle should run on if you choose to run
                                Dozzle (see the -d switch).  Default 50999

  Tasks:
    -g, --generate-only         Generates the data directory and env files and then exits.
    -c, --clean                 Cleans up the verify local startup directory and exits.

    -h, --help                  Show's this help message
EOF
}

# Set the user information to add to Docker
REMOVE_DATA_DIR="echo \"Keeping Data Directory.\""
CLEAN=false
SKIP_BUILD=false
GENERATE_ONLY=false
REBUILD_DATA=false
SKIP_DATA_CHECK=false
THREADS=0
RETRIES=1
YAML_FILE=repos.yml
DOZZLE=false
DOZZLEPORT=50999
WRITE_BUILD_LOG=''
INCLUDE_MAVEN_LOCAL=''
ENABLE_BUILD_LOG=''

while [ "$1" != "" ]; do
    case $1 in
        -y | --yaml-file)            shift
                                     YAML_FILE=$1
                                     ;;
        -t | --threads)              shift
                                     THREADS=$1
                                     ;;
        -r | --retry-build)          shift
                                     RETRIES=$1
                                     ;;
        -b | --skip-build)           SKIP_BUILD=true
                                     ;;
        -w | --write-build-log)      WRITE_BUILD_LOG='-w'
                                     ;;
        -d | --dozzle)               DOZZLE=true
                                     ;;
        -p | --dozzleport)           shift
                                     DOZZLEPORT=$1
                                     ;;
        -R | --rebuild-data)         REBUILD_DATA=true
                                     ;;
        -c | --clean)                CLEAN=true
                                     ;;
        -s | --skip-data-check)      SKIP_DATA_CHECK=true
                                     ;;
        -h | --help)                 show_help
                                     exit 0
                                     ;;
        -g | --generate-only)        GENERATE_ONLY=true
                                     ;;
        -i | --include-maven-local)  INCLUDE_MAVEN_LOCAL='-i'
                                     ;;
        -v | --enable-logging)       ENABLE_BUILD_LOG='-v'
                                     ;;
        * )                          echo -e "Unknown option $1...\n"
                                     show_help
                                     exit 1
    esac
    shift
done

set -eu -o pipefail

case $(uname) in
  Darwin)     STAT="/usr/bin/stat -f %c "
              ;;
  *)          STAT="/usr/bin/stat -c %Y"
              ;;
esac

script_dir="$(cd "$(dirname "$0")" && pwd)"

if ! command -v docker >/dev/null; then
  >&2 echo "docker: command not found. verify-local-startup requires docker."
  exit 1
fi

if which rbenv > /dev/null; then
    if ! rbenv versions |grep "$(cat .ruby-version)" > /dev/null; then
        echo "Using rbenv to install ruby $(cat .ruby-version)..."
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

if [[ $CLEAN == 'true' ]]; then
  clean_up
fi

# Options for rebuilding the data directory
if [[ $SKIP_DATA_CHECK == "false" ]]; then
  check_data_age
fi

if [[ $REBUILD_DATA == "true" ]]; then
  rebuild_data
fi

# Running generate scripts in docker avoids having to install their
# dependencies on the host.
docker build -t verify-local-startup . > /dev/null
docker run -t -v "$script_dir:/verify-local-startup/" verify-local-startup "
set -e
$REMOVE_DATA_DIR
if ! test -d data; then
  generate/hub-dev-pki.sh
fi
./env.sh"

if [[ $GENERATE_ONLY == 'true' ]]; then
  exit 0
fi

if [[ $SKIP_BUILD == 'false' ]]; then
  bundle check || bundle install
  bundle exec ./lib/build-local.rb -R $RETRIES -y $YAML_FILE -t $THREADS $WRITE_BUILD_LOG $INCLUDE_MAVEN_LOCAL $ENABLE_BUILD_LOG
else
  echo "Skipping build process..."
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
