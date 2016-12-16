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
# Build the kernel with allmodconfig configuration
# Call with "-j$(nproc)" to compile with many processes
#
# Environment variables:
#   $KBUILD_OUTPUT  Build directory
#   $CC             C compiler (gcc, clang...)
#   $HOSTCC         Host C Compiler (gcc, clang...)
#   $HOSTCXX        Host C++ Compiler (g++, clang++...)
#   $ALLYESCONFIG   if set to non-empty, build an allyesconfig instead of allmodconfig

# This directory needs to be mounted with the exec flag
export KBUILD_OUTPUT="${KBUILD_OUTPUT:-/tmp/makepkg-$(id -nu)/gitlinux-patched}"

# Build with clang by default
export CC="${CC:-clang}"
export HOSTCC="${HOSTCC:-clang}"

# Guess HOSTCXX from HOSTCC: gcc->g++ and clang->clang++
HOSTCXX_FROM_HOSTCC="$(echo "$HOSTCC" | sed 's/gcc/g/')++"
export HOSTCXX="${HOSTCXX:-$HOSTCXX_FROM_HOSTCC}"

CONFIG_TARGET="${CONFIG_TARGET:-allmodconfig}"
if [ -n "$ALLYESCONFIG" ]
then
    CONFIG_TARGET=allyesconfig
fi

# See also scripts/Makefile.extrawarn for extra warnings enabled with "make W=1, 2 or 3"

export KCFLAGS='-Wall -Wextra -Werror'
KCFLAGS="$KCFLAGS -Wfloat-equal"
KCFLAGS="$KCFLAGS -Wformat=2"
KCFLAGS="$KCFLAGS -Wjump-misses-init"
KCFLAGS="$KCFLAGS -Wlogical-op"
KCFLAGS="$KCFLAGS -Wmissing-format-attribute"
KCFLAGS="$KCFLAGS -Wmissing-include-dirs"
KCFLAGS="$KCFLAGS -Wmissing-prototypes"
KCFLAGS="$KCFLAGS -Wstrict-prototypes"
KCFLAGS="$KCFLAGS -Wtrampolines"
KCFLAGS="$KCFLAGS -Wunknown-pragmas"
KCFLAGS="$KCFLAGS -Wno-aggregate-return" # Linux ktime_get returns a structure
KCFLAGS="$KCFLAGS -Wno-cast-align" # Many struct casts change the alignment
KCFLAGS="$KCFLAGS -Wno-deprecated-declarations"
KCFLAGS="$KCFLAGS -Wno-empty-body" # if (conf) print_debug(...); with empty print_debug
KCFLAGS="$KCFLAGS -Wno-format-nonliteral"
KCFLAGS="$KCFLAGS -Wno-inline" # inline functions can make unlikely code bigger
KCFLAGS="$KCFLAGS -Wno-missing-declarations" # Some drivers love inline without static
KCFLAGS="$KCFLAGS -Wno-missing-field-initializers"
KCFLAGS="$KCFLAGS -Wno-missing-include-dirs" # -Idir/only/in/src is expanded to include both directories in $(srcdir) and output
KCFLAGS="$KCFLAGS -Wno-missing-prototypes" # There are way too many missing #include or static in the code to make this useful
KCFLAGS="$KCFLAGS -Wno-nested-externs" # Linux uses nested externs
KCFLAGS="$KCFLAGS -Wno-old-style-declaration" # inline does not have to be at the beginning of declarations
KCFLAGS="$KCFLAGS -Wno-override-init" # When defining syscall tables, overriding default value is mandatory
KCFLAGS="$KCFLAGS -Wno-pointer-arith" # Linux does arithmetic on void pointers
KCFLAGS="$KCFLAGS -Wno-pointer-sign" # Many functions implicitly cast pointers of different signedness
KCFLAGS="$KCFLAGS -Wno-redundant-decls" # Some headers redefine things
KCFLAGS="$KCFLAGS -Wno-shadow" # The kernel redefines built-in functions like ffs
KCFLAGS="$KCFLAGS -Wno-sign-compare" # There are many comparaisons between signed and unsigned integers
KCFLAGS="$KCFLAGS -Wno-trigraphs" # Ignore trigraphs like "??)"
KCFLAGS="$KCFLAGS -Wno-type-limits" # Unsigned integers >= 0
KCFLAGS="$KCFLAGS -Wno-unused-but-set-variable" # Many variables are never used
KCFLAGS="$KCFLAGS -Wno-unused-const-variable"
KCFLAGS="$KCFLAGS -Wno-unused-function" # Make the build succeed when some static functions are not used
KCFLAGS="$KCFLAGS -Wno-unused-parameter" # There is no __unused macro, and __maybe_unused is not the common headers
KCFLAGS="$KCFLAGS -Wno-error=jump-misses-init" # The compiler is not smart enough in many cases
KCFLAGS="$KCFLAGS -Wno-error=logical-op"
KCFLAGS="$KCFLAGS -Wno-error=write-strings" # TODO, type acpi_string complicates things

if $CC -v 2>&1 | grep -q clang
then
    KCFLAGS="$KCFLAGS -Weverything"
    KCFLAGS="$KCFLAGS -Wno-bad-function-cast" # (unsigned long *)kernel_stack_pointer(...)
    KCFLAGS="$KCFLAGS -Wno-c11-extensions" # Use C11 features
    KCFLAGS="$KCFLAGS -Wno-c99-extensions" # Use C99 features
    KCFLAGS="$KCFLAGS -Wno-c++-compat" # Empty structs exist
    KCFLAGS="$KCFLAGS -Wno-class-varargs" # net/9p passes kuid_t/kgid_t in varargs
    KCFLAGS="$KCFLAGS -Wno-comma" # There are legimitate uses like "while ((n = read(...)), n > 0)"
    KCFLAGS="$KCFLAGS -Wno-constant-logical-operand" # Allow using CONFIG_... in logical expressions
    KCFLAGS="$KCFLAGS -Wno-covered-switch-default" # Covered switch may use "default:BUG();"
    KCFLAGS="$KCFLAGS -Wno-disabled-macro-expansion" # "inline" macro is recursive
    KCFLAGS="$KCFLAGS -Wno-documentation" # don't check documentation strings
    KCFLAGS="$KCFLAGS -Wno-documentation-unknown-command" # don't check documentation strings
    KCFLAGS="$KCFLAGS -Wno-duplicate-decl-specifier" # "const typeof(var)" creates false positives in many places
    KCFLAGS="$KCFLAGS -Wno-empty-translation-unit" # scripts/mod/empty.c is empty
    KCFLAGS="$KCFLAGS -Wno-extended-offsetof" # Use offsetof(type, field.subfield)
    KCFLAGS="$KCFLAGS -Wno-format-invalid-specifier" # clang doesn't know about %Zu
    KCFLAGS="$KCFLAGS -Wno-format-zero-length" # The kernel uses "" format string
    KCFLAGS="$KCFLAGS -Wno-format-non-iso" # "%Lx" is not ISO C
    KCFLAGS="$KCFLAGS -Wno-gnu-variable-sized-type-not-at-end" # Some structures defines "payload" fields in sub-structs
    KCFLAGS="$KCFLAGS -Wno-keyword-macro" # "inline" macro hides a keyword
    KCFLAGS="$KCFLAGS -Wno-ignored-attributes" # "aligned" attribute ignored sometimes
    KCFLAGS="$KCFLAGS -Wno-initializer-overrides" # Syscall tables
    KCFLAGS="$KCFLAGS -Wno-language-extension-token" # Allow "inline"
    KCFLAGS="$KCFLAGS -Wno-long-long" # Use "long long" type
    KCFLAGS="$KCFLAGS -Wno-missing-noreturn" # It does not make sense to have boot functions (rest_init, cpu_idle_loop...) marked __noreturn
    KCFLAGS="$KCFLAGS -Wno-missing-variable-declarations" # Global variables can miss a declaration
    KCFLAGS="$KCFLAGS -Wno-overlength-strings" # Support loooooong strings
    KCFLAGS="$KCFLAGS -Wno-packed" # Packing is much too implicit to be reported
    KCFLAGS="$KCFLAGS -Wno-padded" # Some structures get padded
    KCFLAGS="$KCFLAGS -Wno-pedantic" # Use modern C
    KCFLAGS="$KCFLAGS -Wno-pointer-bool-conversion" # Some vectors are tested as null pointers
    KCFLAGS="$KCFLAGS -Wno-reserved-id-macro" # Linux uses macros begining with underscore
    KCFLAGS="$KCFLAGS -Wno-shift-negative-value" # Shifted negative numbers are like unsigned for Linux
    KCFLAGS="$KCFLAGS -Wno-switch-bool" # It happens that bool are used in switch statements
    KCFLAGS="$KCFLAGS -Wno-switch-enum" # Show values in switch on enum can be skipped
    KCFLAGS="$KCFLAGS -Wno-tautological-compare" # Many unsigned variables are compared with 0
    KCFLAGS="$KCFLAGS -Wno-unknown-pragmas" # Ignore GCC-specific #pragma GCC diagnostic ignored "-Wsuggest-attribute=format"
    KCFLAGS="$KCFLAGS -Wno-unreachable-code" # Code can be unreachable depending on the config
    KCFLAGS="$KCFLAGS -Wno-unreachable-code-break"
    KCFLAGS="$KCFLAGS -Wno-unreachable-code-return"
    KCFLAGS="$KCFLAGS -Wno-used-but-marked-unused" # inline functions are used
    KCFLAGS="$KCFLAGS -Wno-varargs" # There are functions with u8 args before "...", which leads to undefined behavior
    KCFLAGS="$KCFLAGS -Wno-variadic-macros" # Macros with ... in arguments
    KCFLAGS="$KCFLAGS -Wno-vla" # Variable-length arrays are used in compile-time asserts

    # Some things which maybe buggy but whose overhead would be too big to be patches
    KCFLAGS="$KCFLAGS -Wno-assign-enum"
    KCFLAGS="$KCFLAGS -Wno-cast-qual"
    KCFLAGS="$KCFLAGS -Wno-conversion"
    KCFLAGS="$KCFLAGS -Wno-conditional-uninitialized"
    KCFLAGS="$KCFLAGS -Wno-parentheses-equality"
    KCFLAGS="$KCFLAGS -Wno-shorten-64-to-32"
    KCFLAGS="$KCFLAGS -Wno-sign-conversion"
    KCFLAGS="$KCFLAGS -Wno-unneeded-internal-declaration"
    KCFLAGS="$KCFLAGS -Wno-unused-macros" # TODO, macros defined in C files but not used
    KCFLAGS="$KCFLAGS -Wno-shift-sign-overflow" # (1 << 31) is used a lot, but may be replaced by (1U << 31) globally to make this warning more useful

    KCFLAGS="$KCFLAGS -Wno-error=constant-conversion" # TODO ?!? (~0UL in unsigned int)
    KCFLAGS="$KCFLAGS -Wno-error=duplicate-enum" # TODO
    KCFLAGS="$KCFLAGS -Wno-error=enum-conversion" # TODO ?!? (maybe not that important)
    KCFLAGS="$KCFLAGS -Wno-error=gcc-compat" # TODO
    KCFLAGS="$KCFLAGS -Wno-error=switch" # TODO, "overflow converting case value to switch condition type"
elif $CC -v 2>&1 | grep -q 'gcc version'
then
    KCFLAGS="$KCFLAGS -Wno-maybe-uninitialized" # There are too many false positives with gcc 5.2
    KCFLAGS="$KCFLAGS -Wno-frame-address" # __builtin_return_address is called with a nonzero argument
fi

# Initial from Makefile
HOSTCFLAGS='-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89'
# Custom addings
HOSTCFLAGS="$HOSTCFLAGS -g -ggdb"
HOSTCFLAGS="$HOSTCFLAGS -Wextra -Werror"
HOSTCFLAGS="$HOSTCFLAGS -Wfloat-equal"
HOSTCFLAGS="$HOSTCFLAGS -Wformat=2"
HOSTCFLAGS="$HOSTCFLAGS -Winit-self"
HOSTCFLAGS="$HOSTCFLAGS -Winline"
HOSTCFLAGS="$HOSTCFLAGS -Wmissing-declarations"
HOSTCFLAGS="$HOSTCFLAGS -Wmissing-format-attribute"
HOSTCFLAGS="$HOSTCFLAGS -Wmissing-prototypes"
HOSTCFLAGS="$HOSTCFLAGS -Wnested-externs"
HOSTCFLAGS="$HOSTCFLAGS -Wold-style-definition"
HOSTCFLAGS="$HOSTCFLAGS -Wpointer-arith"
HOSTCFLAGS="$HOSTCFLAGS -Wredundant-decls"
HOSTCFLAGS="$HOSTCFLAGS -Wstrict-prototypes"
HOSTCFLAGS="$HOSTCFLAGS -Wunknown-pragmas"
HOSTCFLAGS="$HOSTCFLAGS -Wwrite-strings"
HOSTCFLAGS="$HOSTCFLAGS -Wno-aggregate-return" # str_new() returns struct gstr
HOSTCFLAGS="$HOSTCFLAGS -Wno-cast-align"
HOSTCFLAGS="$HOSTCFLAGS -Wno-format-nonliteral"
HOSTCFLAGS="$HOSTCFLAGS -Wno-missing-field-initializers"
HOSTCFLAGS="$HOSTCFLAGS -Wno-missing-include-dirs" # same as KCFLAGS
HOSTCFLAGS="$HOSTCFLAGS -Wno-shadow"
HOSTCFLAGS="$HOSTCFLAGS -Wno-sign-compare" # There are many comparaisons between signed and unsigned integers
HOSTCFLAGS="$HOSTCFLAGS -Wno-unused-function" # Ignore missing code clean-up
HOSTCFLAGS="$HOSTCFLAGS -Wno-unused-parameter"

if $HOSTCC -v 2>&1 | grep -q clang
then
    HOSTCFLAGS="$HOSTCFLAGS -Weverything"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-c99-extensions"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-cast-qual" # Some pointer casts don't specify const
    HOSTCFLAGS="$HOSTCFLAGS -Wno-comma" # There are legimitate uses like "while ((n = read(...)), n > 0)"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-covered-switch-default" # Some switch one enums cover all values
    HOSTCFLAGS="$HOSTCFLAGS -Wno-disabled-macro-expansion" # Linux has recursive macros
    HOSTCFLAGS="$HOSTCFLAGS -Wno-documentation"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-documentation-unknown-command"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-gnu-conditional-omitted-operand" # "value ? : default" construction
    HOSTCFLAGS="$HOSTCFLAGS -Wno-gnu-empty-initializer"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-gnu-statement-expression"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-gnu-zero-variadic-macro-arguments"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-incompatible-pointer-types-discards-qualifiers" # constant strings get assigned to char* variables
    HOSTCFLAGS="$HOSTCFLAGS -Wno-language-extension-token" # "inline"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-long-long"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-overlength-strings" # Some string literals have more that 509 characters
    HOSTCFLAGS="$HOSTCFLAGS -Wno-padded"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-pedantic"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-reserved-id-macro" # Some macros begins with underscore
    HOSTCFLAGS="$HOSTCFLAGS -Wno-switch-enum" # Show values in switch on enum can be skipped
    HOSTCFLAGS="$HOSTCFLAGS -Wno-unreachable-code-break"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-unused-macros"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-variadic-macros"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-zero-length-array" # Some structures has zero-length arrays
    # Too many occurences to have these in -Werror:
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=conditional-uninitialized"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=conversion"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=declaration-after-statement"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=missing-noreturn"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=missing-variable-declarations"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=sign-conversion"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=shorten-64-to-32"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=unreachable-code"
else
    HOSTCC="${HOSTCC:-gcc}"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-clobbered" # Flase positives of clobbered variables
    HOSTCFLAGS="$HOSTCFLAGS -Wno-discarded-qualifiers" # Many helper programs mix const char* in char* variables
    HOSTCFLAGS="$HOSTCFLAGS -Wno-inline" # Remove funny GCC warnings
    HOSTCFLAGS="$HOSTCFLAGS -Wno-pointer-arith" # Linux does arithmetic on void pointers
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=nested-externs"
    HOSTCFLAGS="$HOSTCFLAGS -Wno-error=redundant-decls"
fi

set -e
set -x

cd "$(dirname -- "$0")/linux"
mkdir -p "$KBUILD_OUTPUT"

# Use allmodconfig
if ! [ -e "$KBUILD_OUTPUT/.config" ]
then
    make HOSTCC="$HOSTCC" HOSTCFLAGS="$HOSTCFLAGS" CC="$CC" "$CONFIG_TARGET"

    # shellcheck disable=SC2129

    # Disable some options
    # I don't want to debug Documentation/ examples.
    echo '# CONFIG_BUILD_DOCSRC is not set' >> "$KBUILD_OUTPUT/.config"
    # gcda is part of compiler_rt library, external, so disable.
    echo '# CONFIG_GCOV_KERNEL is not set' >> "$KBUILD_OUTPUT/.config"
    # some functions use large stack frames when compiling with all options
    echo 'CONFIG_FRAME_WARN=0' >> "$KBUILD_OUTPUT/.config"

    # Modify some options
    # Compress the kernel with XZ
    echo '# CONFIG_KERNEL_GZIP is not set' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_KERNEL_XZ=y' >> "$KBUILD_OUTPUT/.config"
    # Use -fstack-protector-strong
    echo '# CONFIG_CC_STACKPROTECTOR_NONE is not set' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_CC_STACKPROTECTOR_STRONG=y' >> "$KBUILD_OUTPUT/.config"
    # Enable preemption
    echo '# CONFIG_PREEMPT_NONE is not set' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_PREEMPT=y' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_RCU_BOOST=y' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_RCU_KTHREAD_PRIO=1' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_RCU_BOOST_DELAY=1' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_DEBUG_PREEMPT=y' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_PREEMPT_TRACER=y' >> "$KBUILD_OUTPUT/.config"

    if $CC -v 2>&1 | grep -q clang
    then
        # Disable GCC plugins when using clang
        echo '# CONFIG_GCC_PLUGINS is not set' >> "$KBUILD_OUTPUT/.config"
        echo '# CONFIG_KCOV is not set' >> "$KBUILD_OUTPUT/.config"
    fi

    # Merge options
    make HOSTCC="$HOSTCC" HOSTCFLAGS="$HOSTCFLAGS" CC="$CC" oldconfig

    # if allyesconfig, force static linking
    if [ -n "$ALLYESCONFIG" ]
    then
        sed 's/=m$/=y/' -i "$KBUILD_OUTPUT/.config"
    fi
fi

exec make HOSTCC="$HOSTCC" HOSTCFLAGS="$HOSTCFLAGS" CC="$CC" "$@"
