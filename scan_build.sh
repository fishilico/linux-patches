#!/bin/sh
# Run clang analyzer
cd "$(dirname -- "$0")/linux" || exit $?

KBUILD_OUTPUT="/tmp/makepkg-$(id -nu)/gitlinux-patched-noconf"
export KBUILD_OUTPUT

# Use clang
CC=clang
HOSTCC=clang

# Configure with "allnoconfig"
make allnoconfig \
    HOSTCC="$HOSTCC" \
    HOSTCFLAGS="-UCC_HAVE_ASM_GOTO" \
    CC="$CC" \
    KCFLAGS="-UCC_HAVE_ASM_GOTO"

# Run clang's static analyzer
exec scan-build -o ../output-scan-build-noconfig-x86 \
    make -B \
        HOSTCC="$HOSTCC" \
        HOSTCFLAGS="-UCC_HAVE_ASM_GOTO" \
        CC="$CC" \
        KCFLAGS="-UCC_HAVE_ASM_GOTO"
