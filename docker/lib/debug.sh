source show-msg.sh

####################################
# Print and save debug information #
####################################

function debug() {
    show_msg ""
    if [ -f /tmp/hub-docker-debug.log ]; then
        rm /tmp/hub-docker-debug.log
    fi
    LENS=( )
    for i in $(env); do
        KEY=$(echo $i | cut -d '=' -f1)
        LENS=(${LENS[@]} "${#KEY}")
    done
    IFS=$'\n'
    PAD=$(echo "${LENS[*]}" | sort -nr | head -n1)
    KEY="REPO_DIR"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${REPO_DIR}" | tee -a /tmp/hub-docker-debug.log
    KEY="BUILD_COMPOSE_FILE"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${BUILD_COMPOSE_FILE}" | tee -a /tmp/hub-docker-debug.log
    KEY="COMPOSE_FILE"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${COMPOSE_FILE}" | tee -a /tmp/hub-docker-debug.log
    KEY="CONFIG_DIR"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${CONFIG_DIR}" | tee -a /tmp/hub-docker-debug.log
    KEY="ENV_FILE"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${ENV_FILE}" | tee -a /tmp/hub-docker-debug.log
    KEY="SCRIPTPATH"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${SCRIPTPATH}" | tee -a /tmp/hub-docker-debug.log
    KEY="SCRIPT"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${SCRIPT}" | tee -a /tmp/hub-docker-debug.log
    KEY="COMPOSE_CMD"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${COMPOSE_CMD}" | tee -a /tmp/hub-docker-debug.log
    KEY="DOCKER_CMD"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${DOCKER_CMD}" | tee -a /tmp/hub-docker-debug.log
    KEY="OS"
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "$(uname -a)" | tee -a /tmp/hub-docker-debug.log
    KEY="SHELL"
    SHELL=$(readlink /proc/$$/exe)
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${SHELL}" | tee -a /tmp/hub-docker-debug.log
    KEY="SHELL_VERSION"
    SHELLVER=`"$SHELL" --version | head -n 1`
    printf "${RED}${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${SHELLVER}" | tee -a /tmp/hub-docker-debug.log
    printf '\n%b\n' "${RED}${BOLD}Environment:${NORMAL}\n" | tee -a /tmp/hub-docker-debug.log
    KEY="KEY"
    printf "${BOLD}%b${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s   ${BOLD}%s${NORMAL}\n" "${KEY}" " " "VALUE" | tee -a /tmp/hub-docker-debug.log
    printf "${BOLD}===${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s   ${BOLD}=====${NORMAL}\n" " " | tee -a /tmp/hub-docker-debug.log
    for i in $(env|sort); do 
        KEY=$(echo $i | cut -d '=' -f1)
        VALUE=$(echo $i | cut -d '=' -f2)
        printf "${GREEN}%s${NORMAL} %$(( PAD  - ${#KEY} + 2 ))s=> %s\n" "${KEY}" " " "${VALUE}" | tee -a /tmp/hub-docker-debug.log
    done
    show_msg "\nYou can find a copy of this output in /tmp/hub-ddocker-debug.log... Give it to someone who can help."
    exit 0
}