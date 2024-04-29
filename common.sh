#!/bin/sh
#
# Aidan Bird (C) 2024
#
# common variables and functions
#

. "$(dirname "${0}")/logging.sh"

version=1
magic="PXZGPGv${version}"
pwHashLen=64
arg_verbosity='-v'
arg_quiet='-s'
arg_help='-h'
arg_stdout='-O'
arg_help_verbosity='set high verbosity'
arg_help_quiet='suppress output messages'
arg_help_help='show help'
arg_help_stdout='write to stdout'
file_extension='.pxzgpg'

getPassword() {
    password=''
    stty -echo
    read password
    stty echo
    printf '%s' "${password}"
    return 0
}

assert_command_exists gpg
assert_command_exists pixz
assert_command_exists argon2

