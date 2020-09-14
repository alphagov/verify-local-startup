VERIFY_REPOS=( "gds-trusted-developers" "ida-compliance-tool" "ida-hub-support" 
"verify-acceptance-tests" "verify-utils-libs" "verify-build-scripts"
"verify-frontend" "verify-frontend-federation-config" "verify-hub"
"verify-hub-federation-config" "verify-matching-service-adapter" "verify-metadata"
"verify-pki-certs" "verify-saml-libs" "verify-service-provider" "verify-stub-idp" 
"verify-stub-idp-federation-config" "verify-test-rp" "ida-hub-acceptance-tests" )

##############################
# Requirements checking here #
##############################

function check_repo_requirements() {
    show_msg "${INFO} Checking for rquired git repos..."
    if [[ $PULL_REPOS == "true" ]]; then
        show_msg "${INFO} Local repos will be updated... This may take a minute."
    else
        show_msg "${WARN} Skipping git pull; use -p if you want to update your local repos (recommended). "
    fi
    for repo in ${VERIFY_REPOS[@]}; do
        if [ ! -d "${REPO_DIR}/${repo}" ]; then
            show_msg "${ERROR}Missing Repo:${NORMAL} ${repo} is missing or not available."
            FAIL=true
        elif [[ $PULL_REPOS == "true" ]]; then
            if [[ $(git -C ${REPO_DIR}/$repo rev-parse --abbrev-ref HEAD) == "master" ]]; then
                git -C ${REPO_DIR}/$repo pull $GIT_QUIET
            fi
        fi
    done
    if [[ $FAIL == "true" ]]; then
        return 1
    fi
}

function heal_missing_repos() {
    show_msg "${INFO} Pulling down missing repos..."
    for repo in ${VERIFY_REPOS[@]}; do
        if [ ! -d "${REPO_DIR}/${repo}" ]; then
            show_msg "${ERROR}Missing Repo:${NORMAL} ${repo} pulling $repo from git..."
            git clone $GIT_QUIET git@github.com:alphagov/${repo}.git ${REPO_DIR}/$repo
        fi
    done
}

function check_scrips_requirements() {
    if ! which git > /dev/null; then
        show_msg "${ERROR} You need to have ${BOLD}git${NORMAL} installed.  Unable to run script, exiting..."
        exit 1
    fi
    if ! which $DOCKER_CMD > /dev/null; then
        show_msg "${ERROR} You need to have ${BOLD}$DOCKER_CMD${NORMAL} installed.  Unable to run script, exiting..."
        exit 1
    fi
    if ! which $COMPOSE_CMD > /dev/null; then
        show_msg "${ERROR} You need to have ${BOLD}$COMPOSE_CMD${NORMAL} installed.  Unable to run script, exiting..."
        exit 1
    fi
    if ! $DOCKER_CMD info > /dev/null 2>&1; then
        show_msg "${WARN} You really need to be able to run Docker a NORMAL user.  You should add yourself to"
        show_msg "the docker group in /etc/group.  $COMPOSE_CMD will be run using sudo for now."
        COMPOSE_CMD="sudo $COMPOSE_CMD"
        DOCKER_CMD="sudo $DOCKER_CMD"
    fi
}

function check_requirements() {
    check_scrips_requirements
    if ! $COMPOSE_CMD --project-name verify --file $COMPOSE_FILE ps | grep Up > /dev/null 2>&1; then
        check_repo_requirements
        if [ $? != 0 ]; then
            while true; do
                MSG="You have missing repos do you want to pull them from git now? [y/n] "
                if [[ $(readlink /proc/$$/exe) =~ "zsh" ]]; then
                    read "?${MSG}" ynx > /dev/tty
                else
                    read -p "${MSG}" ynx > /dev/tty
                fi
                case $ynx in
                    [Yy]* )     heal_missing_repos
                                unset FAIL
                                check_repo_requirements
                                if [[ $? != 0 ]]; then
                                    show_msg "${ERROR}Unable to fix missing repos automatically.  Please fix them manually and try again."s
                                    exit 1
                                fi
                                break
                                ;;
                    [Nn]* )     show_msg "${ERROR} Please fix the missing repos manually before running the script again."
                                exit 1
                                ;;
                    [Xx]* )     show_msg "${INFO} User cancelled... Exiting..."
                                exit 0
                                ;;
                    * )         show_msg "Please answer yes or no..."
                esac
            done
        fi
    fi
}