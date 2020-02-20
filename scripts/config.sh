#!/usr/bin/env bash
# Central location for Build System configuration

declare -A SecureApt=(
  [debian_10.gpg]="https://ftp-master.debian.org/keys/archive-key-10.asc" \
    [nodesource.gpg]="https://deb.nodesource.com/gpgkey/nodesource.gpg.key"  \
    [lesbonscomptes.gpg]="https://www.lesbonscomptes.com/pages/jf-at-dockes.org.pgp" \
    #TODO Not needed for arm64 and x86
    [raspbian.gpg]="https://archive.raspbian.org/raspbian.public.key" \
  )

export SecureApt
