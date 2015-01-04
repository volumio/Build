#!/bin/bash

SOURCE_URL=http://www.musicpd.org/download/mpd/0.19/mpd-0.19.7.tar.xz

echo 'Creating Temp Dir'
mkdir temp
cd temp
echo 'Getting MPD source tarball'
wget $SOURCE_URL
echo 'Unpacking Source'
tar xvf *.xz
cd mpd-0.19.7

echo 'Debianizing Source'
export DEBFULLNAME="Michelangelo Guarise"
dh_make -f ../mpd-0.19.7.tar.xz -s -e info@volumio.org -p mpd-volumio  

