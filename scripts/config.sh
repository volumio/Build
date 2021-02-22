#!/usr/bin/env bash
# Central location for Build System configuration(s)

declare -A SecureApt=(
  [debian_10.gpg]="https://ftp-master.debian.org/keys/archive-key-10.asc"
  [nodesource.gpg]="https://deb.nodesource.com/gpgkey/nodesource.gpg.key"
  [lesbonscomptes.gpg]="https://www.lesbonscomptes.com/pages/jf-at-dockes.org.pub"
  [deb.kaliko.me.gpg]="https://media.kaliko.me/kaliko.gpg"
  #TODO Not needed for arm64 and x86
  [raspbian.gpg]="https://archive.raspbian.org/raspbian.public.key"
  [raspberrypi.gpg]="http://archive.raspberrypi.org/debian/raspberrypi.gpg.key"
)

# Repo locations that are utilised to create source.list in the rootfs
declare -A APTSOURCE=(
  [Debian]="http://deb.debian.org/debian"
  [Raspbian]="http://raspbian.raspberrypi.org/raspbian/"
)

## Path to the volumio repo
VOLBINSREPO="https://repo.volumio.org/Volumio2/Buster/CustomPackages/"

## Array of volumio binaries
#TODO: Fix naming scheme and repo location
declare -A VOLBINS=(
  [init_updater]="volumio-init-updater-v2"
)

## Array of custom packages
# The expected naming scheme is
# name_version_${BUILD}.deb
# Note the use of $BUILD (arm/armv7/armv8/x86/x64) and not $ARCH(armel/armhf/arm64/i386/amd64) thanks to raspberrypi compatibility naming quirks
declare -A CUSTOM_PKGS=(
  [volumio_remote_updater]="https://repo.volumio.org/Volumio2/Buster/CustomPackages/volumio-remote-updater_1.6"
  [libnpupnp1]="https://repo.volumio.org/Volumio2/Buster/CustomPackages/upmpdcli/libnpupnp1_4.0.14-1"
  [libupnpp6]="https://repo.volumio.org/Volumio2/Buster/CustomPackages/upmpdcli/libupnpp6_0.20.2-1"
  [upmpdcli]="https://repo.volumio.org/Volumio2/Buster/CustomPackages/upmpdcli/upmpdcli_1.5.8-1"
  [shairport-sync]="https://repo.volumio.org/Volumio2/Buster/CustomPackages/shairport-sync/shairport-sync_3.2.2-1"
)

## Backend and Frontend Repository details
VOL_BE_REPO="https://github.com/volumio/Volumio2.git"
VOL_BE_REPO_BRANCH="buster/master"
# VOL_BE_REPO_SHA="d7a5678" # Workaround for BE repo having incompatible package.json for Node v8

## NodeJS Controls
# Semver is only used w.t.r modules fetched from repo,
# actual node version installs only respects the current major versions (Major.x)
# NODE_VERSION=14
NODE_VERSION=14.15.4
# Used to pull the right version of modules
# expected format node_modules_{arm/x86}-v${NODE_VERSION}.tar.gz
NODE_MODULES_REPO="http://repo.volumio.org/Volumio2/"

export SecureApt APTSOURCE VOLBINSREPO VOLBINS VOL_BE_REPO VOL_BE_REPO_BRANCH VOL_BE_REPO_SHA NODE_VERSION NODE_MODULES_REPO CUSTOM_PKGS
