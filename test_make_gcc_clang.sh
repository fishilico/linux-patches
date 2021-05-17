#!/bin/sh
#
# Copyright (c) 2014-2018 Nicolas Iooss
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
msg_yellow() {
    printf '\033[1;33m%s\033[m\n' "$*"
}
set_title() {
    printf '\033]0;%s\007' "$*"
}

# Run the build test with config $1
do_build_test() {
    rm -r "$KBUILD_OUTPUT"
    set_title "Linux:$1"
    export BUILDCONF="$1"
    if ! ./make_allmodconfig.sh "-j$JOBS" -k
    then
        msg_red "Compiling with BUILDCONF=$1 failed."
        set_title "Linux:$1 - failing rebuild"
        ./make_allmodconfig.sh "-j$JOBS" -k
        msg_red "Here are the errors for BUILDCONF=$1"
        set_title "Linux:$1 - failing build"
        ./make_allmodconfig.sh -k || exit $?
        # fall-through if the second compilation succeeded
    fi
}

# List of tests which were not run because something is missing
UNSUPPORTED_TESTS=''

# First compile with gcc
do_build_test gcc || exit $?

# Then recompile with clang
do_build_test clang || exit $?

# Then compile again with gcc in 32-bit mode,
# when linking with libcrypto works (needs lib32-openssl).
# Do not use clang as it does not work yet
# (cf. https://lists.linuxfoundation.org/pipermail/llvmlinux/2014-December/001133.html)
echo 'int main(void){return 0;}' > "$KBUILD_OUTPUT/libcryptotest.c"
if gcc -m32 -Werror "$KBUILD_OUTPUT/libcryptotest.c" -o "$KBUILD_OUTPUT/libcryptotest" -lcrypto
then
    do_build_test gcc-x86_32 || exit $?
else
    UNSUPPORTED_TESTS="$UNSUPPORTED_TESTS gcc-x86_32"
fi

# Now compile for ARM architecture if the compiler is found
if [ "$(uname -m)" = "x86_64" ] && which arm-none-eabi-gcc > /dev/null 2>&1
then
    do_build_test xgcc-arm || exit $?
else
    UNSUPPORTED_TESTS="$UNSUPPORTED_TESTS xgcc-arm"
fi

# Compile for Frama-C if the headers are found and the code is there
if [ -d /usr/share/frama-c/libc ] && [ -d linux/arch/framac/ ]
then
    (
        export CONFIG_TARGET=allnoconfig
        do_build_test gcc-framac
    ) || exit $?

    # Launch Frama-C value analysis
    # ... or not, as recent Frama-C release (20171101) uses waaay too much memory
    #./frama-c_value.sh || exit $?
else
    UNSUPPORTED_TESTS="$UNSUPPORTED_TESTS gcc-framac"
fi

msg_green 'Compiling with all configurations succeeded :)'

# Print a warning for unsupported tests
if [ -n "$UNSUPPORTED_TESTS" ]
then
    msg_yellow "Did not compile with$UNSUPPORTED_TESTS (unsupported on this system)"
fi

# Remove the output directory to free space
rm -r "$KBUILD_OUTPUT"

msg_green 'All done :)'
set_title 'Linux:done :)'
