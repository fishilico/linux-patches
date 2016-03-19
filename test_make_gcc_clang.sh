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

# First compile with gcc
rm -r "$KBUILD_OUTPUT"
if ! HOSTCC=gcc CC=gcc ./make_allmodconfig.sh "-j$JOBS" -k
then
    printf '\033[1;31mCompiling with gcc failed.\033[m\n'
    HOSTCC=gcc CC=gcc ./make_allmodconfig.sh -k || exit $?
    # fall-through if the second compilation succeeded
fi

# Then recompile with clang
rm -r "$KBUILD_OUTPUT"
if ! ./make_allmodconfig.sh "-j$JOBS" -k
then
    printf '\033[1;31mCompiling with clang failed.\033[m\n'
    ./make_allmodconfig.sh -k || exit $?
    # fall-through if the second compilation succeeded
fi

printf '\033[1;32mCompiling with gcc and clang succeded :)\033[m\n'

LOGFILE="make.log_clang_$(date '+%Y-%m-%d')"
echo "Compiling with clang and logging to $LOGFILE"
rm -r "$KBUILD_OUTPUT"
./make_allmodconfig.sh -j1 -k > "$LOGFILE" 2>&1 || exit $?
printf '\033[1;32mAll done :)\033[m\n'
