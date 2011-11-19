#!/usr/bin/env bash

get_email()
{
    USERNAME=$1
    PASSWORD=$2

    get private_email/get "username=$USERNAME&password=$PASSWORD"
}

[ $# = 2 ] && {
    CWD="$(dirname "$0")"
    . "$CWD/common.sh"

    get_email "$@"
}
