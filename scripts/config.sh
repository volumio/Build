#!/usr/bin/env bash
# Central location for Build System configuration

declare -A SecureApt=(
  [nodesource.gpg]="https://deb.nodesource.com/gpgkey/nodesource.gpg.key"  \
    [debian_10.gpg]="https://ftp-master.debian.org/keys/archive-key-10.asc" \
    [raspbian.gpg]="https://archive.raspbian.org/raspbian.public.key" \
  )
