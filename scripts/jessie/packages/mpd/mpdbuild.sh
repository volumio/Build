#!/bin/bash

SOURCE_URL=http://www.musicpd.org/download/mpd/0.19/mpd-0.19.7.tar.xz

echo 'Installing Required Packages'
apt-get -y  install devscripts
echo 'Installing Dependencies'
apt-get -y build-dep mpd
echo 'Getting MPD source tarball'
wget $SOURCE_URL
echo 'Unpacking Source'
tar xvf *.xz
cd mpd-0.19.7

echo 'Debianizing Source'
export DEBFULLNAME="Michelangelo Guarise"
dh_make -f ../mpd-0.19.7.tar.xz -s -e info@volumio.org -p mpd-volumio  
cp -r ../debian mpd-0.19.7
echo 'Compiling into Deb Package'
debuild binary
