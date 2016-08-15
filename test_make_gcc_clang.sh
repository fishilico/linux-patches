#!/bin/sh
#
# Copyright (c) 2014-2016 Nicolas Iooss
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Test building Linux with both gcc and clang
cd "$(dirname -- "$0")" || exit $?

JOBS="${JOBS:-4}"
KBUILD_OUTPUT="/tmp/makepkg-$(id -nu)/gitlinux-patched"

# Helper functions for xterm terminal
msg_green() {
    printf '\033[1;32m%s\033[m\n' "$*"
}
msg_red() {
    printf '\033[1;31m%s\033[m\n' "$*"
}
set_title() {
    printf '\033]0;%s\007' "$*"
}

# Run the build test named after $1
do_build_test() {
    rm -r "$KBUILD_OUTPUT"
    set_title "Linux:$1"
    if ! ./make_allmodconfig.sh "-j$JOBS" -k
    then
        msg_red "Compiling with $1 failed."
        ./make_allmodconfig.sh -k || exit $?
        # fall-through if the second compilation succeeded
    fi
}

# First compile with gcc
(
    export CC=gcc
    export HOSTCC=gcc
    export HOSTCXX=g++
    do_build_test gcc
) || exit $?

# Then recompile with clang
(
    export CC=clang
    export HOSTCC=clang
    export HOSTCXX=clang++
    do_build_test clang
) || exit $?

# Now compile for ARM architecture if the compiler is found
if [ "$(uname -m)" = "x86_64" ] && which arm-none-eabi-gcc > /dev/null 2>&1
then
    (
        export ARCH=arm
        export CROSS_COMPILE=arm-none-eabi-
        # Define __linux__ in the compiler
        export CC='arm-none-eabi-gcc -D__linux__'
        export HOSTCC=gcc
        export HOSTCXX=g++
        do_build_test arm-gcc
    ) || exit $?
fi

msg_green 'Compiling with gcc and clang succeded :)'

LOGFILE="make.log_clang_$(date '+%Y-%m-%d')"
echo "Compiling with clang and logging to $LOGFILE"
rm -r "$KBUILD_OUTPUT"
set_title 'Linux:clang with log'
./make_allmodconfig.sh -j1 -k > "$LOGFILE" 2>&1 || exit $?
msg_green 'All done :)'
set_title 'Linux:done :)'
