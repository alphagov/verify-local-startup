#!/usr/bin/env bash

script_dir="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
find $script_dir -type f | xargs cat | shasum | cut -d ' ' -f 1
