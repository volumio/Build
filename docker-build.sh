#!/bin/bash

# Docker based image builder
#
# This is an alternative method for building a volumio image that does not
# require the user to have a debian system with specific packages versions.
#
# This method relies on a pre-built docker container that will perform the
# whole build process and generate the required image in the local directory.

DOCKER="docker"

DPATH=$(which "${DOCKER}" 2> /dev/null)
FOUND=$?
RUNDATE=$(date "+%Y-%m-%d")

if [ "${FOUND}" != "0" ]; then
	echo "You need to have ${DOCKER} installed to be able to perform a Docker based build"
	exit 1
fi

if [ $# -lt 2 ]; then
	echo "Missign build parameters!"
	echo
	echo "This script is a wrapper around the main ./build.sh script, and as such it requires specific parameters"
	echo "to be passed over to build.sh."
	echo
	echo "Please run the command ./build.sh without parameters for a full help."
	exit 2
fi

${DOCKER} run -it --rm --name=volumio-build --privileged \
	-v ${PWD}:/build piffio/volumio-build \
	$@ | tee docker-build-${RUNDATE}.log
