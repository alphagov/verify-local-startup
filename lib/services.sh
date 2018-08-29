#!/usr/bin/env bash

build_service() {
  local basedir="$1"

  pushd "$basedir" >/dev/null
    if test -x "./gradlew"; then
      echo -n "Building in $(tput setaf 3)$basedir$(tput sgr0) ... "
      if ./gradlew --parallel build installDist -x intTest -x test > build-output.log 2>&1; then
        echo "$(tput setaf 2)done$(tput sgr0)"
      else
        echo "$(tput setaf 1)failed$(tput sgr0) - see build-output.log"
      fi
    fi
  popd >/dev/null
}

start_service_checker() {
  local service="$1"
  local port="$2"
  local pid="$3"
  local log="$4"
  local endpoint="$5"
  local s=1
  local MAX_RETRIES=10

  for i in $(seq 1 $MAX_RETRIES); do
    curl --silent --output /dev/null $endpoint
    s=$?
    test "$s" -eq 0 && break || sleep 5
  done

  if test "$s" -eq 0; then
    printf "$(tput setaf 3)%-25s$(tput sgr0) $(tput setaf 2)STARTED$(tput sgr0) [pid: $pid | port: $port]\n" "$service"
  else
    printf "$(tput setaf 3)%-25s$(tput sgr0) $(tput setaf 1)FAILED$(tput sgr0) see $log\n" "$service"
    exit 1
  fi
}

start_service() {
  local service="$1"
  local basedir="$2"
  local cfg="$3"
  local port="$4"
  local debug_port=$(($port+2))
  local java_args="${@:5}"
  local debug="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=$debug_port"
  local startup_script="${basedir}/build/install/$service/bin/$service"
  local log="logs/${service}_console.log"

  mkdir -p logs

  pids=`ps aux | grep java | grep "$cfg" | awk '{print $2}'`
  for pid in $pids; do kill -9 $pid 2>/dev/null; done

  echo "Starting service: $(tput setaf 3)$service$(tput sgr0)"
  export JAVA_OPTS="$java_args \
      -Xms32m -Xmx32m"
  ( rm -f "$log"
    $startup_script server "$cfg" >"$log" 2>&1 &
    pid=$!

    start_service_checker $service $port $pid $log "localhost:$port/service-status"
  ) &
}
