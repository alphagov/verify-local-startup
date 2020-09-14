#!/bin/bash
# Define colors and styles
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
GDSBG=$(tput setab 033)
GDS="${GDSBG}${WHITE}"

INFO="[ ${GREEN}INFO${NORMAL} ]\t"
WARN="[ ${YELLOW}WARN${NORMAL} ]\t"
ERROR="[ ${RED}ERROR${NORMAL} ]\t"
DEBUG="[ ${CYAN}DEBUG${NORMAL} ]\t"
TROUBLESHOOTING="[ ${MAGENTA}${BOLD}TROUBLESHOOTING${NORMAL} ]\t"