#!/usr/bin/env bash

# Some general helpers for the Volumio Build system

# Terminal colors if supported
if test -t 1; then # if terminal
	ncolors=$(which tput > /dev/null && tput colors) # supports color
	if test -n "$ncolors" && test $ncolors -ge 8; then
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
log()
{
  local tmp=""
  [[ -n $3 ]] && tmp="${normal}[${yellow} $3 ${normal}]"

  case $2 in
    err)
      echo -e "[${red} ${bold}error ${normal}]${red} $1 ${normal}$tmp"
      ;;

    wrn)
      echo -e "[${magenta}${bold} warn ${normal}] $1 $tmp"
      ;;

    dbg)
      echo -e "[${standout} dbg ${normal}] ${blue} $1 ${normal} $tmp"
      ;;

    info)
      echo -e "[${green} .... ${normal}]${cyan} $1 $tmp ${normal}"
      ;;

    okay)
      echo -e "[${green} o.k. ${normal}]${green} $1 ${normal} $tmp"
      ;;

		"")
			echo -e "[${green} .. ${normal}] $1 $tmp "
			;;

    *)
			[[ !  -z  $2  ]] && tmp="[${yellow} $2 ${normal}]"
      echo -e "[${green} .. ${normal}] $1 $tmp "
      ;;

  esac
}

# Check if device/path is mounted
# where: -r = --raw, -n = --noheadings, -o = --output
# return exit codes: 0 = found, 1 = not found
isMounted() { findmnt -rno SOURCE,TARGET "$1" >/dev/null;}

time_it() {
	time=$(( $1-$2 ))
	if [[ $time -lt 60 ]]; then
		time_str="$time sec"
	else
		time_str="$(( time/60 )) min"
	fi
	export time_str
}
