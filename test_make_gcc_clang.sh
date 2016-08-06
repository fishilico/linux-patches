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

# First compile with gcc
rm -r "$KBUILD_OUTPUT"
set_title 'Linux:gcc'
if ! HOSTCC=gcc HOSTCXX=g++ CC=gcc ./make_allmodconfig.sh "-j$JOBS" -k
then
    msg_red 'Compiling with gcc failed.'
    HOSTCC=gcc CC=gcc ./make_allmodconfig.sh -k || exit $?
    # fall-through if the second compilation succeeded
fi

# Then recompile with clang
rm -r "$KBUILD_OUTPUT"
set_title 'Linux:clang'
if ! HOSTCC=clang HOSTCXX=clang++ CC=clang ./make_allmodconfig.sh "-j$JOBS" -k
then
    msg_red 'Compiling with clang failed.'
    HOSTCC=clang CC=clang ./make_allmodconfig.sh -k || exit $?
    # fall-through if the second compilation succeeded
fi

msg_green 'Compiling with gcc and clang succeded :)'

LOGFILE="make.log_clang_$(date '+%Y-%m-%d')"
echo "Compiling with clang and logging to $LOGFILE"
rm -r "$KBUILD_OUTPUT"
set_title 'Linux:clang with log'
./make_allmodconfig.sh -j1 -k > "$LOGFILE" 2>&1 || exit $?
msg_green 'All done :)'
set_title 'Linux:done :)'
