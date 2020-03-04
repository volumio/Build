#!/bin/sh

if [ -e "/boot/ssh" ]; then
  echo "SSH file found, enabling SSH service"
  /usr/bin/sudo /bin/systemctl start ssh
fi
