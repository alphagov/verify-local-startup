#!/bin/bash

version() {
cat > /dev/tty << EOF

${BOLD}Hub Docker Script Version 1.0${NORMAL}
(c) ${GDS}${BOLD} GDS ${NORMAL} 2020
(c) Crown Copyright 2020

EOF
}

usage() {
    version
    cat  > /dev/tty << EOF
${BOLD}Usage:${NORMAL}
    Basic usage ${BOLD}./hub-docker.sh${NORMAL} to start the hub running in docker.
    Run ${BOLD}./hub-docker.sh${NORMAL} again to stop the hub running in docker.

${BOLD}Run Options:${NORMAL}
    ${BOLD}${GREEN}-b  --build${NORMAL}                  Build the various java components before running the hub in Docker
    ${BOLD}${GREEN}-l  --logs${NORMAL}                   Shows the logs from the verify hub is running in Docker
    ${BOLD}${GREEN}-n  --no-dozzle${NORMAL}              Prevent the script from running Dozzle
    ${BOLD}${GREEN}-p  --pull-repos${NORMAL}             Pull all related repos before running (Highly recommended but off by default)
    ${BOLD}${GREEN}-r  --restart${NORMAL}                Restarts the Verify Hub if its running in Docker
    ${BOLD}${GREEN}-R  --rm-images${NORMAL}              Remove the existing docker images

${BOLD}Config Options:${NORMAL}
    ${BOLD}${YELLOW}-c  --config-dir [PATH]${NORMAL}      Specifies the configuration directory to get the microservices running
    ${BOLD}${YELLOW}${NORMAL}                             The default is ${BOLD}${CONFIG_DIR}${NORMAL}
    ${BOLD}${YELLOW}-d  --dev-dir [PATH]${NORMAL}         Specify your verify development directory.  $COMPOSE_CMD and this script
    ${BOLD}${YELLOW}${NORMAL}                             will look for all related repos in this directory.
    ${BOLD}${YELLOW}${NORMAL}                             The default is ${BOLD}${REPO_DIR}${NORMAL}
    ${BOLD}${YELLOW}-e  --env-file [PATH]${NORMAL}        Specifies the environment file used to get the hub up and running
    ${BOLD}${YELLOW}${NORMAL}                             The default is ${BOLD}${ENV_FILE}${NORMAL}

${BOLD}Standard Options${NORMAL}
    ${BOLD}${BLUE}-N  --no-colours${NORMAL}             Disable script colours
    ${BOLD}${BLUE}-v  --version${NORMAL}                Shows version details
    ${BOLD}${BLUE}-V  --verbose${NORMAL}                Shows command output for debugging...
    ${BOLD}${BLUE}${NORMAL}                             You'll need to Ctrl-C to exit and shutdown the hub
    ${BOLD}${BLUE}-h  --help${NORMAL}                   Shows this usage message

${BOLD}Troubleshooting Options${NORMAL}
    ${BOLD}${RED}--troubleshoot${NORMAL}               Theres some basic steps which can be done to troubleshoot making the hub
    ${BOLD}${RED}${NORMAL}                             work in docker.  Mostly removing everything, rebuilding and starting again.
    ${BOLD}${RED}${NORMAL}                             Thats what this option does and should be a first port of call if things
    ${BOLD}${RED}${NORMAL}                             don't work as expected.
    ${BOLD}${RED}--debug${NORMAL}                      Print debug information to console and save it to "/tmp/debug.log"
    ${BOLD}${RED}${NORMAL}                             This works well with -N.  If you've reached this point then you should
    ${BOLD}${RED}${NORMAL}                             also supply any other command line options you've used with it.
    ${BOLD}${RED}--kill-with-fire${NORMAL}             Kill with fire does exactly what its name suggests.  Its part of the
    ${BOLD}${RED}${NORMAL}                             troubleshooting steps above but instead of triggering a rebuild it stops
    ${BOLD}${RED}${NORMAL}                             at the point everything is clean again.  Useful for tear downs and moving on.

EOF
}

short_usage() {
    cat  > /dev/tty << EOF
${BOLD}Usage:${NORMAL}
Basic usage ${BOLD}./hub-docker.sh${NORMAL} to start the hub running in docker.
Run ${BOLD}./hub-docker.sh${NORMAL} again to stop the hub running in docker.

${BOLD}Run Options:${NORMAL}
    ${BOLD}${RED}-b  --build${NORMAL}                  Build the various java components before running the hub in Docker
    ${BOLD}${RED}-l  --logs${NORMAL}                   Shows the logs from the verify hub is running in Docker
    ${BOLD}${RED}-n  --no-dozzle${NORMAL}              Prevent the script from running Dozzle
    ${BOLD}${RED}-p  --pull-repos${NORMAL}             Pull all related repos before running (Highly recommended but off by default)
    ${BOLD}${RED}-r  --restart${NORMAL}                Restarts the Verify Hub if its running in Docker
    ${BOLD}${RED}-R  --rm-images${NORMAL}              Remove the existing docker images

${BOLD}Config Options:${NORMAL}
    ${BOLD}${RED}-c  --config-dir [PATH]${NORMAL}      Specifies the configuration directory to get the microservices running
    ${BOLD}${RED}${NORMAL}                             The default is ${BOLD}${CONFIG_DIR}${NORMAL}
    ${BOLD}${RED}-d  --dev-dir [PATH]${NORMAL}         Specify your verify development directory.  $COMPOSE_CMD and this script
    ${BOLD}${RED}${NORMAL}                             will look for all related repos in this directory.
    ${BOLD}${RED}${NORMAL}                             The default is ${BOLD}${REPO_DIR}${NORMAL}
    ${BOLD}${RED}-e  --env-file [PATH]${NORMAL}        Specifies the environment file used to get the hub up and running
    ${BOLD}${RED}${NORMAL}                             The default is ${BOLD}${ENV_FILE}${NORMAL}

${BOLD}Standard Options${NORMAL}
    ${BOLD}${RED}-N  --no-colours${NORMAL}             Disable script colours
EOF
}