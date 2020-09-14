#!/bin/bash
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`

# Check for lib dir to load requirements
if [ ! -d $SCRIPTPATH/lib ]; then
    echo -e "Lib directory is missing!  Script unable to run.  Exiting..."
    exit 9
fi

show_msg() {
    printf '%b\n' "${1}" > /dev/tty
}

# Source files from lib
source $SCRIPTPATH/lib/colours.sh
source $SCRIPTPATH/lib/usage.sh
source $SCRIPTPATH/lib/path-resolver.sh
source $SCRIPTPATH/lib/requirements-checker.sh

#########################
# Script Functions here #
#########################

function hubbuild() {
    if [[ ! -f ${SCRIPTPATH}/.build.lock || $BUILD == "true" ]]; then
        show_msg "${INFO} Building HUB Java Components...${NORMAL}"
        $COMPOSE_CMD --project-name verify-builder --file $BUILD_COMPOSE_FILE up
        show_msg "${INFO} Cleaning up build phase...${NORMAL}"
        $COMPOSE_CMD --project-name verify-builder --file $BUILD_COMPOSE_FILE rm -fsv
        # Clean up network and volume images
        $DOCKER_CMD network rm verify-builder_default
        $DOCKER_CMD volume rm verify-builder_maven-repository verify-builder_verify-frontend-gem
        if [ -f ${SCRIPTPATH}/.build.lock ]; then
            rm .build.lock
        fi
        touch .build.lock
    fi
}

function dozzle_start() {
    if [[ $NO_DOZZLE == "true" ]]; then
        return
    fi
    if ! docker ps |grep verify_dozzle_1 > /dev/null; then
        if [[ $(uname) == "Darwin" ]]; then
            show_msg "${WARN} On Mac OS you should think about turning off dozzle with the ${BOLD}-n${NORMAL} option and using Docker Dashboard instead."
        fi
        show_msg "${INFO} ${GREEN}Starting Dozzle Log Viewer in Docker...${NORMAL}"
        $DOCKER_CMD run --rm --name verify_dozzle_1 --detach --volume=/var/run/docker.sock:/var/run/docker.sock -p 50999:8080 amir20/dozzle
        show_msg "${INFO} The Dozzle log viewer is now running and available at: http://localhost:50999"
    fi
}

function dozzle_stop() {
    if docker ps |grep verify_dozzle_1 > /dev/null; then
        show_msg "${INFO} Dozzle log viewer is running... ${RED}Stopping...${NORMAL}"
        $DOCKER_CMD stop verify_dozzle_1
        show_msg "${INFO} ${GREEN}Dozzle log viewer has stopped${GREEN}"
    fi
}

function hubstart() {
    hubbuild
    dozzle_start
    show_msg "${INFO} ${GREEN}Starting Verify Hub in Docker...${NORMAL}"
    $COMPOSE_CMD --project-name verify --env-file $ENV_FILE --file $COMPOSE_FILE up --no-start
    $COMPOSE_CMD --project-name verify --env-file $ENV_FILE --file $COMPOSE_FILE start
    EX=$?
    if [[ $EX == 0 ]]; then
        sleep 10
        show_msg "${INFO} The Verify Hub is running...  Goto http://localhost:50130/test-rp"
        exit 0
    else
        show_msg "${ERROR} ${RED}Failed to start verify hub in Docker${NORMAL}"
        exit $EX
    fi
}

function hubstop() {
    show_msg "${INFO} Verify Hub is running in Docker... ${RED}Stopping...${NORMAL}"
    $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE stop
    EX=$?
    show_msg "${INFO} ${GREEN}Hub docker has stopped${NORMAL}"
    dozzle_stop
    exit $EX
}

function hubrestart() {
    if  $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE ps | grep Up; then
        $COMPOSE_CMD --project-name verify --env-file $ENV_FILE --file $COMPOSE_FILE restart
        exit $?
    else
        # If the hub isn't running... start the hub
        hubstart
    fi
}

function service() {
    if [[ $RESTART == "true" ]]; then
        hubrestart
    fi

    if  $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE ps | grep Up; then
        hubstop
    else
        hubstart
    fi
}

function logs() {
    if  $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE ps | grep Up; then
        exec > /dev/tty
        $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE logs
        exit $?
    else
        show_msg "${ERROR} ${RED}Verify hub isn't running in Docker... Can't show logs.${NORMAL}"
        exit 1
    fi
}

function remove_images() {
    while true; do
            MSG="Are you sure you want to remove all your docker images? [y/n] "
            if [[ $(readlink /proc/$$/exe) =~ "zsh" ]]; then
                read "?${MSG}" ynx > /dev/tty
            else
                read -p "${MSG}" ynx > /dev/tty
            fi
            case $ynx in
                [Yy]* )     show_msg "${WARN} Removing existing docker images...  They'll be recreated when you next run the script."
                            dozzle_stop
                            $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE rm -s -v -f
                            exit $?
                            ;;
                [Nn]* )     exit 0
                            ;;
                [Xx]* )     exit 0
                            ;;
                * )         show_msg "Please answer yes or no..."
            esac
        done    
}

function remove_everything() {
    show_msg "${TROUBLESHOOTING} Removing everything..."
    show_msg "${TROUBLESHOOTING} Stopping all hub containers which may still be running..."
    $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE stop
    show_msg "${TROUBLESHOOTING} Removing all existing containers..."
    $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE rm -s -v -f
    show_msg "${TROUBLESHOOTING} Removing hub docker volumes..."
    if $DOCKER_CMD volume inspect verify_database-data > /dev/null 2>&1; then
        docker rm verify_database-data
    fi
    if $DOCKER_CMD volume inspect verify_redis-config > /dev/null 2>&1; then
        docker rm verify_redis-config
    fi
    if $DOCKER_CMD volume inspect verify_verify-frontend-gem > /dev/null 2>&1; then
        docker rm verify_verify-frontend-gem
    fi
    if $DOCKER_CMD volume inspect verify_database-data > /dev/null 2>&1; then
        docker rm verify_redis-data
    fi
    show_msg "${TROUBLESHOOTING} Removing hub docker network..."
    if $DOCKER_CMD network inspect verify_hub-network > /dev/null 2>&1; then
        $DOCKER_CMD network rm verify_hub-network
    fi
    show_msg "${TROUBLESHOOTING} Stopping Dozzle log viewer..."
    dozzle_stop
    show_msg "${TROUBLESHOOTING} Removing .build.lock file..."
    rm $SCRIPTPATH/.build.lock
}

function troubleshoot() {
    show_msg "${RED}${BOLD}Starting troubleshooting steps...${NORMAL}"
    remove_everything
    if [[ $KILLWITHFIRE == "true" ]]; then
        show_msg "${TROUBLESHOOTING} Everything has been stop and removed.  Exiting..."
        exit 0
    fi
    dozzle_start
    show_msg "${TROUBLESHOOTING} Triggering hub build process to build Java components..."
    hubbuild
    show_msg "${TROUBLESHOOTING} Building hub containers..."
    $COMPOSE_CMD --project-name verify --env-file $ENV_FILE --file $COMPOSE_FILE up --no-start
    show_msg "${TROUBLESHOOTING} Starting Hub Containers..."
    $COMPOSE_CMD --project-name verify --env-file $ENV_FILE --file $COMPOSE_FILE start
    exit $?
}

################################
# Main script body starts here #
################################

# Set default options
RES_PATH="/"
RUN_AS_SERVICE=false
NO_DOZZLE=false
RESTART=false
BUILD=false
LOGS=false
RM_IMGS=false
PULL_REPOS=false
REPO_DIR="${SCRIPTPATH}/../.."
COMPOSE_FILE=${SCRIPTPATH}/hub-docker-compose.yml
BUILD_COMPOSE_FILE=${SCRIPTPATH}/hub-build-docker-compose.yml
ENV_FILE=${SCRIPTPATH}/hub.env
CONFIG_DIR=${SCRIPTPATH}/../configuration
VERBOSE=false

# Set internal variables
COMPOSE_CMD=docker-compose
DOCKER_CMD=docker

# Process commandline arguments
while [ "$1" != "" ]; do
    case $1 in
        -b | --build        )   BUILD=true
                                ;;
        -n | --no-dozzle    )   NO_DOZZLE=true
                                ;;
        -r | --restart      )   RESTART=true
                                ;;
        -l | --logs         )   LOGS=true
                                ;;
        -e | --env-file     )   shift
                                USER_ENV_FILE=$1
                                ;;
        -d | --dev-dir      )   shift
                                USER_REPO_DIR=$1
                                ;;
        -c | --config-dir   )   shift
                                USER_CONFIG_DIR=$1
                                ;;
        -R | --rm-images    )   RM_IMGS=true
                                ;;
        -p | --pull-repos   )   PULL_REPOS=true
                                ;;
        -N | --no-colours   )   source lib/no-colours.sh
                                ;;
        -V | --verbose      )   VERBOSE=true
                                ;;
        -v | --version      )   version
                                exit
                                ;;
        -h | --help         )   usage
                                exit 0
                                ;;
        --troubleshoot      )   TROUBLESHOOT=true
                                ;;
        --kill-with-fire    )   KILLWITHFIRE=true
                                ;;
        --debug             )   SHOW_DEBUG=true
                                source lib/debug.sh
                                ;;
        *                   )   echo -e "Unknown option $1...\n"
                                usage
                                exit 1
    esac
    shift
done

resolve_paths
check_requirements

if [[ $SHOW_DEBUG == "true" ]]; then
    debug
fi

# Export the config dir
export CONFIG_DIR="${CONFIG_DIR}"
export REPO_DIR="${REPO_DIR}"

# Silence output
if [[ $VERBOSE == "false" ]]; then
    exec > /dev/null
    GIT_QUIET="-q"
fi

if [[ $TROUBLESHOOT == "true" || $KILLWITHFIRE == "true" ]]; then
    troubleshoot
fi

if [[ $RM_IMGS == "true" ]]; then
    remove_images
fi

if [[ $LOGS == "true" ]]; then
    logs
fi

if [[ $VERBOSE == "false" ]]; then
    service
fi

# If we end up here bring up docker
# logs and all... You'll need to
# ctrl-c to exit.
hubbuild
dozzle_start
if docker ps |grep verify-dozzle > /dev/null; then
    show_msg "${WARN} Remember to stop Dozzle with ${BOLD}`$DOCKER_CMD rm verify-dozzle`${NORMAL} when you are done"
fi
$COMPOSE_CMD  --project-name verify --env-file $ENV_FILE --file $COMPOSE_FILE up
