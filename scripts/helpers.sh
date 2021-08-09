#!/usr/bin/env bash
# shellcheck disable=SC2155

# Some general helpers for the Volumio Build system

# Terminal colors if supported
if [[ ${TERM} == dumb ]]; then
	export TERM=ansi
fi
if test -t; then                                      # if terminal
	ncolors=$(command -v tput >/dev/null && tput colors) # supports colour
	if [[ ${ncolors} -ge 8 ]]; then
		export termcols=$(tput cols)
		export bold="$(tput bold)"
		export underline="$(tput smul)"
		export standout="$(tput smso)"
		export normal="$(tput sgr0)"
		export black="$(tput setaf 0)"
		export red="$(tput setaf 1)"
		export green="$(tput setaf 2)"
		export yellow="$(tput setaf 3)"
		export blue="$(tput setaf 4)"
		export magenta="$(tput setaf 5)"
		export cyan="$(tput setaf 6)"
		export white="$(tput setaf 7)"
	fi
fi

# Make logging a bit more legible and intuitive
log() {
	local tmp=""
	local char=".."
	if [[ ${CHROOT} == yes ]]; then
		char="--"
	fi

	[[ -n $3 ]] && tmp="${normal}[${yellow} $3 ${normal}]"

	case $2 in
	err)
		echo -e "[${red} ${bold}error ${normal}]${red} $1 ${normal}${tmp}"
		;;

	cfg)
		echo -e "[${cyan} ${bold}cfg ${normal}]${yellow} $1 ${normal}${tmp}"
		;;

	wrn)
		echo -e "[${magenta}${bold} warn ${normal}] $1 ${tmp}"
		;;

	dbg)
		echo -e "[${standout} dbg ${normal}] ${blue} $1 ${normal} ${tmp}"
		;;

	info)
		echo -e "[${green} ${char}${char} ${normal}]${cyan} $1 ${tmp} ${normal}"
		;;

	okay)
		echo -e "[${green} o.k. ${normal}]${green} $1 ${normal} ${tmp}"
		;;

	"")
		echo -e "[${green} ${char} ${normal}] $1 ${tmp}"
		;;

	*)
		[[ -n $2 ]] && tmp="[${yellow} $2 ${normal}]"
		echo -e "[${green} ${char} ${normal}] $1 ${tmp}"
		;;

	esac
}

# Check if device/path is mounted
# where: -r = --raw, -n = --noheadings, -o = --output
# return exit codes: 0 = found, 1 = not found
isMounted() { findmnt -rno SOURCE,TARGET "$1" >/dev/null; }

time_it() {
	time=$(($1 - $2))
	if [[ ${time} -lt 60 ]]; then
		TIME_STR="${time} sec"
	else
		TIME_STR="$((time / 60)):$((time % 60)) min"
	fi
	export TIME_STR
}

check_size() {
	local path=$1
	if [[ -e "${path}" ]]; then
		du -sh0 "${path}" 2>/dev/null | cut -f1
	else
		echo ""
	fi
}

DISTRO_VER="$(lsb_release -s -r)"
DISTRO_NAME="$(lsb_release -s -c)"

export DISTRO_VER DISTRO_NAME
