#!/usr/bin/env bash

CWD="$(dirname "$0")"
INCLUDES="common.sh change_email.sh get_email.sh"
for I in $INCLUDES;do
    . "$CWD/$I"
done

USERNAME=t1
PASSWORD=hejhej
EMAIL1="$USERNAME@test.com"
EMAIL2="$USERNAME@test.com"
EMAIL3="$USERNAME@test.com"


expect_change_email()
{
    expect '"ok"' change_email "$USERNAME" "$PASSWORD" "$1"
}

expect_email()
{
    expect "\"$1\"" get_email "$USERNAME"
}

expect_change_email "$EMAIL1"
expect_email "$EMAIL1"
expect_change_email "$EMAIL2"
expect_email "$EMAIL2"
expect_change_email "$EMAIL3"
expect_email "$EMAIL3"
expect_change_email "$EMAIL1"
expect_email "$EMAIL1"

