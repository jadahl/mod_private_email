#!/usr/bin/sh

change_email()
{
    JSON=`cat << __EOF__
{
    "username":"$1",
    "host":"$HOST",
    "password":"$2",
    "new_email":"$3",
    "key":"$KEY"
}
__EOF__`
    request private_email/change "$JSON"
}

[ $# = 4 ] && {
    CWD="$(dirname "$0")"
    . "$CWD/common.sh"

    change_email "$@"
}

