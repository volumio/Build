#!/bin/bash

docker run --privileged --tty -v ${PWD}:/build piffio/volumio-build -d pi -b arm -v 3.001
