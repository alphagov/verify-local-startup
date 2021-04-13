#!/usr/bin/env bash

show_help() {
  cat << EOF
Usage:
    -l,  --list                  List available services and their status

    -s,  --start                 Start a service which has been stopped.
                                 NOTE: This does not do a build use the -r option for that
    -r,  --restart               Restart/Rolls a service
    -S,  --stop                  Stop a running service

    -rm, --remove                Stops (if running) and removes a component
    -rb, --rebuild               Forces rebuilding of a compoent
                                 NOTE: This removes and rebuilds a component it will also
                                       restart the component if it was running at the time.
                                       
    -h,  --help                  Show's this help message
EOF
}

ACTION=none
while [ "$1" != "" ]; do
    case $1 in
        -l  | --list)           ACTION=list
                                ;;
        -s  | --start)          ACTION=start
                                shift
                                COMPONENT=$1
                                ;;
        -r  | --restart)        ACTION=restart
                                shift
                                COMPONENT=$1
                                ;;
        -S  | --stop)           ACTION=stop
                                shift
                                COMPONENT=$1
                                ;;
        -rm | --remove)         ACTION=remove
                                shift
                                COMPONENT=$1
                                ;;
        -rb | --rebuild)        ACTION=rebuild
                                shift
                                COMPONENT=$1
                                ;;
        -h  | --help)           show_help
                                exit 0
                                ;;
        * )                     echo -e "Unknown option $1...\n"
                                show_help
                                exit 1
    esac
    shift
done

bundle check 2>&1 > /dev/null
if [[ $? != 0 ]]; then
    bundle install
fi

case $ACTION in
    list)       bundle exec ./lib/components.rb -l ;;
    start)      bundle exec ./lib/components.rb -s $COMPONENT ;;
    restart)    bundle exec ./lib/components.rb -r $COMPONENT ;;
    stop)       bundle exec ./lib/components.rb -S $COMPONENT ;;
    remove)     bundle exec ./lib/components.rb -rm $COMPONENT ;;
    rebuild)    bundle exec ./lib/components.rb -rb $COMPONENT ;;
    *)          show_help
                exit 0
esac
