#!/usr/bin/env sh

# Use override file to run acceptance-tests in the same network
docker_compose="docker-compose -f ../verify-acceptance-tests/docker-compose.yml -f acceptance-tests.override.yml"

trap "$docker_compose down" EXIT

$docker_compose build test-runner
$docker_compose run \
                -e TEST_ENV=docker-local \
                test-runner
