#!/bin/sh
#
# Aidan Bird (C) 2024
#
# logging functions for scripts
#

export LC_ALL=C

me="$(basename "${0}")"

default_verbosity_level=1

verbosity_level=${default_verbosity_level}

usage=""

log_error() {
    [ "${verbosity_level}" -ge 1 ] && { >&2 echo -e "${me}:[E]: ${1}" ; }
}

log_info() {
    [ "${verbosity_level}" -ge 1 ] && { echo -e "${me}:[I]: ${1}" ; }
}

log_detail() {
    [ "${verbosity_level}" -ge 2 ] && { echo -e "${me}:[D]: ${1}" ; }
}

log_detail_error() {
    [ "${verbosity_level}" -ge 2 ] && { echo -e "${me}:[E]: ${1}" ; }
}

exec_detail() {
    [ "${verbosity_level}" -ge 2 ] && [ -n "${1}" ] && { eval "${1}" ; }
}

log_usage_and_die() {
    log_error "${usage}"
    exit 1
}

log_error_and_die() {
    log_error "${1}"
    exit 1
}

assert_last_program_ok() {
    if [ "${?}" -ne 0 ]
    then
        log_error "${1}"
        exit 1
    fi
}

assert_running_as_root() {
    [ "$(id -u)" -ne 0 ] && { log_error_and_die 'run as root.'; }
}

assert_command_exists() {
    command -v "${1}" > /dev/null
    assert_last_program_ok "${1} is required"
}

