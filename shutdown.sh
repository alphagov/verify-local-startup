#!/usr/bin/env bash

show_help() {
  cat << EOF
Usage:
    -d, --dozzle                Prevent shutdown from killing Dozzle as well.
    -h, --help                  Show's this help message
EOF
}

KILL_DOZZLE=true
while [ "$1" != "" ]; do
    case $1 in
        -d | --dozzle)          KILL_DOZZLE=false
                                ;;
        -h | --help)            show_help
                                exit 0
                                ;;
        * )                     echo -e "Unknown option $1...\n"
                                show_help
                                exit 1
    esac
    shift
done

tput setaf 5 
cat << 'EOF'
   _____ __          __  __  _                ____                    
  / ___// /_  __  __/ /_/ /_(_)___  ____ _   / __ \____ _      ______ 
  \__ \/ __ \/ / / / __/ __/ / __ \/ __ `/  / / / / __ \ | /| / / __ \
 ___/ / / / / /_/ / /_/ /_/ / / / / /_/ /  / /_/ / /_/ / |/ |/ / / / /
/____/_/ /_/\__,_/\__/\__/_/_/ /_/\__, /  /_____/\____/|__/|__/_/ /_/ 
                                 /____/   Bye-bye! 
EOF
tput sgr0

if [[ $KILL_DOZZLE == "true" ]]; then
   DOZZLE=$(docker ps --format "{{.Names}}" |grep dozzle |grep verify)
   if [[ $? == 0 ]]; then
      echo "Stopping Verify Dozzle"
      docker stop $DOZZLE 2>&1 > /dev/null
   fi
fi

docker-compose down
