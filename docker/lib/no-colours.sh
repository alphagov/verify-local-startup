#!/bin/bash
# Define colors and styles
BLACK=""
RED=""
GREEN=""
YELLOW=""
LIME_YELLOW=""
POWDER_BLUE=""
BLUE=""
MAGENTA=""
CYAN=""
WHITE=""
BRIGHT=$(tput bold)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
GDS="${REVERSE}${BOLD}"

INFO="[ INFO ]\t"
WARN="[ WARN ]\t"
ERROR="[ ERROR ]\t"
DEBUG="[ DEBUG ]\t"
TROUBLESHOOTING="[ ${BOLD}TROUBLESHOOTING${NORMAL} ]\t"