#!/usr/bin/env bash

cd "$(dirname "$0")"
shasum_args="$(test -n "$1" && echo "-c $1")"
find generate -type f -print0 | xargs -0 shasum | shasum $shasum_args
