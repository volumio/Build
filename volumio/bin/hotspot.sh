#!/bin/sh

set -eux

say() {
  printf '%s\n' "$1"
}

die() {
  say "$0: $1" >& 2
  exit 1
}

usage() {
  say "usage: $0 device" >&2
  exit 1
}

[ $# -eq 1 ] || usage

hostapd() {
  DRIVER=$(/sbin/ethtool -i "$1" | awk -F': ' '/driver/ {print $2}')
  ARCH=$(/usr/bin/dpkg --print-architecture)
  if [ x"$DRIVER" = x"rtl8192cu" -a x"$ARCH" = x"armhf" ] ; then
    say '-edimax'
  else
    say ''
  fi
}

interface() {
  say "$(sed -n -e '/^interface=/{s,^interface=,,;p;q;}')"
}

set -- "$1" "$(hostapd "$1")"
set -- "$1" "/usr/sbin/hostapd$2" "/etc/hostapd/hostapd$2.conf"
set -- "$1" "$(interface < "$3")" "$2" "$3"

[ x"$1" = x"$2" ] ||
  die "Inconsistent network interface: $1 $2"

rm -rf /var/run/hostapd

set -- "$3" -g "/var/run/hostapd/$1" "$4"
exec "$@"
