#!/usr/bin/env bash

get_email()
{
    USERNAME=$1

    get private_email/get "username=$USERNAME"
}

[ $# = 2 ] && {
    CWD="$(dirname "$0")"
    . "$CWD/common.sh"

    get_email "$@"
}
