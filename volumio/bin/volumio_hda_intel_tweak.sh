#!/bin/bash

for card in /sys/class/sound/card*; do
  cardno=$(cat $card/number)
  chip=$(amixer -c $cardno info | grep "Mixer name" | awk -F": " '{print (substr($2, 2, length($2) - 2))}')
  cardname=$(cat /proc/asound/cards | grep "$(cat $card/number) \[$(cat $card/id)" | awk -F" - " '{print $2}')
  case $cardname in
  "HDA Intel PCH")
    case $chip in
    "Realtek ALC283")
      # not all HDA Intel PCH/ ALC283 have spdif out ==> mixer may be missing
      mixer_exists=$(amixer -c 0 | grep "IE958,16")
      if [ ! "x$mixer_exists" == "x" ]; then
        /usr/bin/amixer -c $cardno set IEC958,16 unmute
      fi
      ;;
    "Realtek ALC892")
      /usr/bin/amixer -c $cardno set Front,0 mute
      /usr/bin/amixer -c $cardno set Surround,0 mute
      /usr/bin/amixer -c $cardno set Center,0 mute
      /usr/bin/amixer -c $cardno set LFE,0 mute
      /usr/bin/amixer -c $cardno set IEC958,16 unmute
      ;;
    "IDT 92HD81B1X5") ;;

    esac
    ;;
  esac
done
exit 0
