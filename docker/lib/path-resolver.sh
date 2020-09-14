#################################################
# Resolve Paths and make sure we can find files #
#################################################

function path_resolver() {
    if [[ $(uname) == "Linux" ]]; then
        RES_PATH=$(readlink -f $1)
    else
        if which greadlink > /dev/null; then
            RES_PATH=$(greadlink -f $1)
        elif which python > /dev/null; then
            RES_PATH=$(python -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' $1)
        else
            return 1
        fi
    fi
}

function resolve_repo_dir() {
    if [ -z $USER_REPO_DIR ]; then
        path_resolver $REPO_DIR
        if [[ $? == 0 ]]; then
            REPO_DIR=${RES_PATH}
        else
            show_msg "${ERROR} Can't resolve dev-dir please supply it using the -d option..."
            short_usage
            exit 1
        fi
    else
        path_resolver $USER_REPO_DIR
        if [[ $? == 0 ]]; then
            REPO_DIR=${RES_PATH}
        else
            REPO_DIR=${USER_REPO_DIR}
        fi
    fi
    export REPO_DIR=${REPO_DIR}
}

function resolve_user_env() {
    if [ -z $USER_ENV_FILE ]; then
        path_resolver $ENV_FILE
        if [[ $? == 0 ]]; then
            ENV_FILE=${RES_PATH}
        else
            show_msg "${ERROR} Can't resolve env_file please supply it using the -e option..."
            short_usage
            exit 1
        fi
    else
        path_resolver $USER_ENV_FILE
        if [[ $? == 0 ]]; then
            ENV_FILE=${RES_PATH}
        else
            ENV_FILE=${USER_ENV_FILE}
        fi
    fi
    export ENV_FILE=${ENV_FILE}
}

function resolve_user_config() {
    if [ -z $USER_CONFIG_DIR ]; then
        path_resolver $CONFIG_DIR
        if [[ $? == 0 ]]; then
            CONFIG_DIR=${RES_PATH}
        else
            show_msg "${ERROR} Can't resolve config-dir please supply it using the -c option..."
            short_usage
            exit 1
        fi
    else
        path_resolver $USER_CONFIG_DIR
        if [[ $? == 0 ]]; then
            CONFIG_DIR=${RES_PATH}
        else
            CONFIG_DIR=${USER_CONFIG_DIR}
        fi
    fi
    export CONFIG_DIR=${CONFIG_DIR}
}

function resolve_paths() {
    resolve_repo_dir
    resolve_user_env
    resolve_user_config
}