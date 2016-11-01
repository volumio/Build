#!/bin/bash

TAR=/etc/logdirs.tar

echo "Preparing /var/log directory tree"
ls "/var/log" 1>/dev/null || exit 1
if [ ! -f "$TAR" ]; then
     echo "Can't find '$TAR', skipping"
     exit 0
fi

cd /
tar xf "$TAR"

unset TAR

echo "Finalizing"
sync

