#!/usr/bin/env bash
# Launch Frama-C value plugin
cd "$(dirname -- "$0")" || exit $?

KBUILD_OUTPUT="${KBUILD_OUTPUT:-/tmp/makepkg-$(id -nu)/gitlinux-patched}"

set -o pipefail

# Do not run if the system does not have enough available memory (at least 9 GB)
MEMAVAIL="$(sed -n 's/^MemAvailable: *\([0-9]\+\) kB$/\1/p' /proc/meminfo)"
MEMNEEDED=9000000
if [ -n "$MEMAVAIL" ] && [ "$MEMAVAIL" -lt "$MEMNEEDED" ]
then
    echo >&2 "Not enough available memory ($MEMAVAIL KB/$MEMNEEDED KB). Avoiding system freeze now!"
    exit
fi

# shellcheck disable=SC2046
frama-c -save frama-linux.sav 2>&1 \
    -cpp-command 'cat %1 > %2' \
    -machdep gcc_x86_32 \
    -main _start \
    -val -context-depth=2 -val-show-progress \
    $(find "$KBUILD_OUTPUT" \
        \( \
            -path 'kernel/bounds.i' -o \
            -path 'scripts' -o \
            -name '.*.i' \) -prune -o \
        -name '*.i' -print |sort) | \
while IFS= read -r LINE
do
    # Filter out some spammy lines from Frama-C output

    # Skip file:line prefix
    MESSAGE="$(echo "$LINE" | cut -d: -f3-)"
    # Silent some warnings
    if  [ "$MESSAGE" = '[kernel] Case label -1 exceeds range of unsigned int for switch expression. Nothing to worry.' ] || \
        [ "$MESSAGE" = '[kernel] Dropping side-effect in sizeof. Nothing to worry, this is by the book.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Call to ____ilog2_NaN in constant. Ignoring this call and returning 0.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Call to __ilog2_u32 in constant. Ignoring this call and returning 0.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Call to __ilog2_u64 in constant. Ignoring this call and returning 0.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Call to __roundup_pow_of_two in constant. Ignoring this call and returning 0.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Clobber list contain "memory" argument. Assuming no side-effect beyond those mentioned in output operands.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Length of array is zero. This GCC extension is unsupported. Assuming length is 1.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Unknown aligned attribute syntax: keeping it as is and adding new one.' ] || \
        [ "$MESSAGE" = '[kernel] warning: Unsupported packing pragma not honored by Frama-C.' ]
    then
        continue
    fi

    # Don't show false positive (non-returning functions)
    # Buggy fall-through functions would be catched by the compiler before Frama-C
    RE='^\[kernel\] warning: Body of function [a-zA-Z0-9_]* falls-through. Adding a return statement'
    [[ "$MESSAGE" =~ $RE ]] && continue

    # Skip a weak declaration seen after a real one
    RE='^\[kernel\] warning: def.n of func [a-zA-Z0-9_]* at .* conflicts with the one at .*; keeping the one at '
    [[ "$MESSAGE" =~ $RE ]] && continue

    # Drop some warnings which are reported when computing initial state
    RE='^\[kernel\] warning: alignment attribute ".*" not understood on struct '
    [[ "$LINE" =~ $RE ]] && continue

    # Reformat the output to see the relative path in the source tree
    echo "${LINE/linux\//linux: }"

    # Quit when Frama-C starts dumping the initial state
    if [ "$LINE" = '[value] Initial state computed' ]
    then
        break
    fi
done

# Exiting with SIGPIPE (return value 128+13) is okay
if [ $? -eq 141 ]
then
    exit
fi
