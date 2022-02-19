#!/bin/sh
#
# Copyright (c) 2014-2022 Nicolas Iooss
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

# Select a build configuration from BUILDCONF variable, if it exists
case "${BUILDCONF:-}" in
    gcc)
        # Native gcc
        CC=gcc
        HOSTCC=gcc
        HOSTCXX=g++
        ;;
    clang)
        # Native clang
        CC=clang
        HOSTCC=clang
        HOSTCXX=clang++
        ;;
    gcc-x86_32)
        # gcc in 32-bit x86 mode
        ARCH=i386
        CC='gcc -m32'
        HOSTCC='gcc -m32'
        HOSTCXX='g++ -m32'
        ;;
    xgcc-arm)
        # ARM with arm-none-eabi-... cross-compiling toolchain
        ARCH=arm
        CROSS_COMPILE=arm-none-eabi-
        # Define __linux__ in the compiler
        CC='arm-none-eabi-gcc -D__linux__'
        HOSTCC=gcc
        HOSTCXX=g++
        ;;
    gcc-framac)
        # Use gcc with Frama-C special architecture
        ARCH=framac
        CC=gcc
        HOSTCC=gcc
        HOSTCXX=g++
        ;;
    '')
        # Build with clang by default
        CC="${CC:-clang}"
        HOSTCC="${HOSTCC:-clang}"
        # Guess HOSTCXX from HOSTCC: gcc->g++ and clang->clang++
        HOSTCXX_FROM_HOSTCC="$(echo "$HOSTCC" | sed 's/gcc/g/')++"
        HOSTCXX="${HOSTCXX:-$HOSTCXX_FROM_HOSTCC}"
        ;;
    *)
        echo >&2 "Unknown build configuration $BUILDCONF"
        exit 1
        ;;
esac

# export all variables
export ARCH CC CROSS_COMPILE HOSTCC HOSTCXX

# Define the target used for configuration
CONFIG_TARGET="${CONFIG_TARGET:-allmodconfig}"
if [ -n "$ALLYESCONFIG" ]
then
    CONFIG_TARGET=allyesconfig
fi

# Disable the specified warning in $KCFLAGS if it is supported by the compiler
disable_in_kcflags() {
    # shellcheck disable=SC2086
    if $CC -Werror $KCFLAGS "-W$1" -E - < /dev/null >/dev/null 2>&1
    then
        KCFLAGS="$KCFLAGS -Wno-$1"
    else
        echo >&2 "Warning: unsupported CC ($CC) flag -W$1"
    fi
}

# Disable the specified warning in $HOSTCFLAGS if it is supported by the compiler
disable_in_hostcflags() {
    # shellcheck disable=SC2086
    if $HOSTCC -Werror $HOSTCFLAGS "-W$1" -E - < /dev/null >/dev/null 2>&1
    then
        HOSTCFLAGS="$HOSTCFLAGS -Wno-$1"
    else
        echo >&2 "Warning: unsupported HOSTCC ($HOSTCC) flag -W$1"
    fi
}

# See also scripts/Makefile.extrawarn for extra warnings enabled with "make W=1, 2 or 3"

export KCFLAGS='-Wall -Wextra -Werror'
KCFLAGS="$KCFLAGS -Wfloat-equal"
KCFLAGS="$KCFLAGS -Wformat=2"
KCFLAGS="$KCFLAGS -Wmissing-format-attribute"
KCFLAGS="$KCFLAGS -Wmissing-include-dirs"
KCFLAGS="$KCFLAGS -Wmissing-prototypes"
KCFLAGS="$KCFLAGS -Wstrict-prototypes"
KCFLAGS="$KCFLAGS -Wunknown-pragmas"
disable_in_kcflags 'address-of-packed-member' # Linux takes references to unaligned members of packed structs
disable_in_kcflags 'aggregate-return' # Linux ktime_get returns a structure
disable_in_kcflags 'array-bounds' # gcc 10 and clang 13 warn about array subscripts with negative value, which is used
disable_in_kcflags 'cast-align' # Many struct casts change the alignment
disable_in_kcflags 'deprecated-declarations'
disable_in_kcflags 'empty-body' # if (conf) print_debug(...); with empty print_debug
disable_in_kcflags 'format-nonliteral'
disable_in_kcflags 'implicit-fallthrough' # Many switch statements use fall-though cases
disable_in_kcflags 'inline' # inline functions can make unlikely code bigger
disable_in_kcflags 'missing-declarations' # Some drivers love inline without static
disable_in_kcflags 'missing-field-initializers'
disable_in_kcflags 'missing-include-dirs' # -Idir/only/in/src is expanded to include both directories in $(srcdir) and output
disable_in_kcflags 'missing-prototypes' # There are way too many missing #include or static in the code to make this useful
disable_in_kcflags 'nested-externs' # Linux uses nested externs
disable_in_kcflags 'pointer-arith' # Linux does arithmetic on void pointers
disable_in_kcflags 'pointer-sign' # Many functions implicitly cast pointers of different signedness
disable_in_kcflags 'redundant-decls' # Some headers redefine things
disable_in_kcflags 'shadow' # The kernel redefines built-in functions like ffs
disable_in_kcflags 'sign-compare' # There are many comparaisons between signed and unsigned integers
disable_in_kcflags 'trigraphs' # Ignore trigraphs like "??)"
disable_in_kcflags 'type-limits' # Unsigned integers >= 0
disable_in_kcflags 'unused-but-set-variable' # Many variables are never used
disable_in_kcflags 'unused-const-variable'
disable_in_kcflags 'unused-function' # Make the build succeed when some static functions are not used
disable_in_kcflags 'unused-parameter' # There is no __unused macro, and __maybe_unused is not the common headers
disable_in_kcflags 'error=enum-conversion' # TODO ?!? (maybe not that important)
disable_in_kcflags 'error=write-strings' # TODO, type acpi_string complicates things

if $CC -v 2>&1 | grep -q clang
then
    KCFLAGS="$KCFLAGS -Weverything"
    disable_in_kcflags 'atomic-implicit-seq-cst' # __sync_add_and_fetch() and __sync_bool_compare_and_swap() trigger warnings
    disable_in_kcflags 'bad-function-cast' # (unsigned long *)kernel_stack_pointer(...)
    disable_in_kcflags 'c11-extensions' # Use C11 features
    disable_in_kcflags 'c99-extensions' # Use C99 features
    disable_in_kcflags 'c++-compat' # Empty structs exist
    disable_in_kcflags 'c++98-compat' # Linux uses __auto_type in WARN macro
    disable_in_kcflags 'class-varargs' # net/9p passes kuid_t/kgid_t in varargs
    disable_in_kcflags 'comma' # There are legimitate uses like "while ((n = read(...)), n > 0)"
    disable_in_kcflags 'compound-token-split-by-space' # Some macros separate ( and { by a newline
    disable_in_kcflags 'constant-logical-operand' # Allow using CONFIG_... in logical expressions
    disable_in_kcflags 'covered-switch-default' # Covered switch may use "default:BUG();"
    disable_in_kcflags 'disabled-macro-expansion' # "inline" macro is recursive
    disable_in_kcflags 'documentation' # don't check documentation strings
    disable_in_kcflags 'documentation-unknown-command' # don't check documentation strings
    disable_in_kcflags 'duplicate-decl-specifier' # "const typeof(var)" creates false positives in many places
    disable_in_kcflags 'empty-translation-unit' # scripts/mod/empty.c is empty
    disable_in_kcflags 'extended-offsetof' # Use offsetof(type, field.subfield)
    disable_in_kcflags 'extra-semi-stmt' # Many ';' with no effect
    disable_in_kcflags 'format-invalid-specifier' # clang doesn't know about %Zu
    disable_in_kcflags 'format-zero-length' # The kernel uses "" format string
    disable_in_kcflags 'format-non-iso' # "%Lx" is not ISO C
    disable_in_kcflags 'gnu-variable-sized-type-not-at-end' # Some structures defines "payload" fields in sub-structs
    disable_in_kcflags 'keyword-macro' # "inline" macro hides a keyword
    disable_in_kcflags 'ignored-attributes' # "aligned" attribute ignored sometimes
    disable_in_kcflags 'ignored-optimization-argument' # Ignore unsupported -falign-jumps=1 and -falign-loops=1
    disable_in_kcflags 'initializer-overrides' # Syscall tables
    disable_in_kcflags 'language-extension-token' # Allow "inline"
    disable_in_kcflags 'long-long' # Use "long long" type
    disable_in_kcflags 'missing-noreturn' # It does not make sense to have boot functions (rest_init, cpu_idle_loop...) marked __noreturn
    disable_in_kcflags 'missing-variable-declarations' # Global variables can miss a declaration
    disable_in_kcflags 'null-pointer-arithmetic' # The kernel uses horrible syntax such as "return NULL + !*ppos;"
    disable_in_kcflags 'null-pointer-subtraction' # The kernel uses subtraction with NULL in ACPI_OFFSET and other places
    disable_in_kcflags 'overlength-strings' # Support loooooong strings
    disable_in_kcflags 'packed' # Packing is much too implicit to be reported
    disable_in_kcflags 'padded' # Some structures get padded
    disable_in_kcflags 'pedantic' # Use modern C
    disable_in_kcflags 'pointer-bool-conversion' # Some vectors are tested as null pointers
    disable_in_kcflags 'redundant-parens' # Some macros expand with redundant parentheses
    disable_in_kcflags 'reserved-id-macro' # Linux uses macros beginning with underscore
    disable_in_kcflags 'reserved-identifier'
    disable_in_kcflags 'shift-negative-value' # Shifted negative numbers are like unsigned for Linux
    disable_in_kcflags 'string-concatenation' # Some drivers concatenate strings to make them pretty
    disable_in_kcflags 'switch-bool' # It happens that bool are used in switch statements
    disable_in_kcflags 'switch-enum' # Show values in switch on enum can be skipped
    disable_in_kcflags 'tautological-compare' # Many unsigned variables are compared with 0
    disable_in_kcflags 'tautological-type-limit-compare' # Make sure the kernel keeps type bounding checks
    disable_in_kcflags 'tautological-unsigned-enum-zero-compare' # Many unsigned enums are compared with 0
    disable_in_kcflags 'tautological-unsigned-zero-compare' # Many unsigned variables are compared with 0
    disable_in_kcflags 'tautological-value-range-compare' # Some 1-bit unsigned value are compared with -1 in macros
    disable_in_kcflags 'unknown-pragmas' # Ignore GCC-specific #pragma GCC diagnostic ignored "-Wsuggest-attribute=format"
    disable_in_kcflags 'unreachable-code' # Code can be unreachable depending on the config
    disable_in_kcflags 'unreachable-code-break'
    disable_in_kcflags 'unreachable-code-return'
    disable_in_kcflags 'used-but-marked-unused' # inline functions are used
    disable_in_kcflags 'varargs' # There are functions with u8 args before "...", which leads to undefined behavior
    disable_in_kcflags 'variadic-macros' # Macros with ... in arguments
    disable_in_kcflags 'vla' # Variable-length arrays are used in compile-time asserts
    disable_in_kcflags 'void-pointer-to-enum-cast' # Many "any" field can carry the value of an enum

    # Some things which maybe buggy but whose overhead would be too big to be patches
    disable_in_kcflags 'assign-enum'
    disable_in_kcflags 'cast-qual'
    disable_in_kcflags 'conversion'
    disable_in_kcflags 'conditional-uninitialized'
    disable_in_kcflags 'parentheses-equality'
    disable_in_kcflags 'shorten-64-to-32'
    disable_in_kcflags 'sign-conversion'
    disable_in_kcflags 'unneeded-internal-declaration'
    disable_in_kcflags 'unused-macros' # TODO, macros defined in C files but not used
    disable_in_kcflags 'shift-sign-overflow' # (1 << 31) is used a lot, but may be replaced by (1U << 31) globally to make this warning more useful

    disable_in_kcflags 'error=constant-conversion' # TODO ?!? (~0UL in unsigned int)
    disable_in_kcflags 'error=duplicate-enum' # TODO
    disable_in_kcflags 'error=gcc-compat' # TODO
    disable_in_kcflags 'error=switch' # TODO, "overflow converting case value to switch condition type"
elif $CC -v 2>&1 | grep -q 'gcc version'
then
    KCFLAGS="$KCFLAGS -Wtrampolines"
    KCFLAGS="$KCFLAGS -Wjump-misses-init"
    KCFLAGS="$KCFLAGS -Wlogical-op"
    disable_in_kcflags 'aggressive-loop-optimizations' # gcc 9 warns about some loops in echoaudio_dsp, which looks fine
    disable_in_kcflags 'attribute-alias' # gcc 8 warns about x86-32 syscall handler using incompatible types
    disable_in_kcflags 'builtin-declaration-mismatch' # gcc 9 warns about using specific pointer types instead of void*
    disable_in_kcflags 'cast-function-type' # gcc 8 warns about many incompatible function casts used by Linux
    disable_in_kcflags 'format-overflow' # Many calls to snprintf may overflow
    disable_in_kcflags 'format-truncation' # Many calls to snprintf may be truncated
    disable_in_kcflags 'frame-address' # __builtin_return_address is called with a nonzero argument
    disable_in_kcflags 'maybe-uninitialized' # There are too many false positives with gcc 5.2
    disable_in_kcflags 'old-style-declaration' # inline does not have to be at the beginning of declarations
    disable_in_kcflags 'override-init' # When defining syscall tables, overriding default value is mandatory
    disable_in_kcflags 'packed-not-aligned' # gcc 8 warns about __attribute__((packed, aligned(4))) because 4 < 8
    disable_in_kcflags 'restrict' # gcc 10 warns about sprintf with overlapping arguments
    disable_in_kcflags 'sizeof-pointer-memaccess' # gcc 8 warns about using the size of the source buffer
    disable_in_kcflags 'stringop-truncation' # gcc 8 warns about using strncpy with a dest buffer having the specified size
    disable_in_kcflags 'stringop-overflow' # gcc 8 warns about using strncpy when "specified bound depends on the length of the source argument"
    disable_in_kcflags 'zero-length-bound' # bound-checking zero-length arrays does not work

    disable_in_kcflags 'error=jump-misses-init' # The compiler is not smart enough in many cases
    disable_in_kcflags 'error=logical-op'
else
    echo >&2 "Unknown compiler $CC"
    exit 1
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
disable_in_hostcflags 'aggregate-return' # str_new() returns struct gstr
disable_in_hostcflags 'cast-align'
disable_in_hostcflags 'format-nonliteral'
disable_in_hostcflags 'implicit-fallthrough' # Many switch statements use fall-though cases
disable_in_hostcflags 'missing-field-initializers'
disable_in_hostcflags 'missing-include-dirs' # same as KCFLAGS
disable_in_hostcflags 'shadow'
disable_in_hostcflags 'sign-compare' # There are many comparaisons between signed and unsigned integers
disable_in_hostcflags 'unused-function' # Ignore missing code clean-up
disable_in_hostcflags 'unused-parameter'

if $HOSTCC -v 2>&1 | grep -q clang
then
    HOSTCFLAGS="$HOSTCFLAGS -Weverything"
    disable_in_hostcflags 'alloca' # host programs may use alloca()
    disable_in_hostcflags 'bad-function-cast' # (void *)(uintptr_t)function(...) in scripts/dtc
    disable_in_hostcflags 'c99-extensions'
    disable_in_hostcflags 'c++-compat' # Empty structs are used in ARRAY_SIZE
    disable_in_hostcflags 'cast-qual' # Some pointer casts don't specify const
    disable_in_hostcflags 'comma' # There are legimitate uses like "while ((n = read(...)), n > 0)"
    disable_in_hostcflags 'compound-token-split-by-space' # Some macros separate ( and { by a newline
    disable_in_hostcflags 'covered-switch-default' # Some switch one enums cover all values
    disable_in_hostcflags 'disabled-macro-expansion' # Linux has recursive macros
    disable_in_hostcflags 'extra-semi-stmt' # # Many ';' with no effect in scripts/kconfig and scripts/dtc
    disable_in_hostcflags 'documentation'
    disable_in_hostcflags 'documentation-unknown-command'
    disable_in_hostcflags 'gnu-conditional-omitted-operand' # "value ? : default" construction
    disable_in_hostcflags 'gnu-empty-initializer'
    disable_in_hostcflags 'gnu-statement-expression'
    disable_in_hostcflags 'gnu-zero-variadic-macro-arguments'
    disable_in_hostcflags 'incompatible-pointer-types-discards-qualifiers' # constant strings get assigned to char* variables
    disable_in_hostcflags 'language-extension-token' # "inline"
    disable_in_hostcflags 'long-long'
    disable_in_hostcflags 'overlength-strings' # Some string literals have more that 509 characters
    disable_in_hostcflags 'packed' # Ignore warnings about unnecessary __attribute__((packed))
    disable_in_hostcflags 'padded'
    disable_in_hostcflags 'pedantic'
    disable_in_hostcflags 'reserved-id-macro' # Some macros begins with underscore
    disable_in_hostcflags 'reserved-identifier'
    disable_in_hostcflags 'switch-enum' # Show values in switch on enum can be skipped
    disable_in_hostcflags 'unreachable-code-break'
    disable_in_hostcflags 'unused-macros'
    disable_in_hostcflags 'used-but-marked-unused'
    disable_in_hostcflags 'variadic-macros'
    disable_in_hostcflags 'vla' # Variable-length arrays are used in some host programs
    disable_in_hostcflags 'zero-length-array' # Some structures has zero-length arrays
    # Too many occurrences to have these in -Werror:
    disable_in_hostcflags 'error=conditional-uninitialized'
    disable_in_hostcflags 'error=conversion'
    disable_in_hostcflags 'error=declaration-after-statement'
    disable_in_hostcflags 'error=missing-noreturn'
    disable_in_hostcflags 'error=missing-variable-declarations'
    disable_in_hostcflags 'error=sign-conversion'
    disable_in_hostcflags 'error=shorten-64-to-32'
    disable_in_hostcflags 'error=unreachable-code'
elif $HOSTCC -v 2>&1 | grep -q 'gcc version'
then
    HOSTCC="${HOSTCC:-gcc}"
    disable_in_hostcflags 'clobbered' # Flase positives of clobbered variables
    disable_in_hostcflags 'discarded-qualifiers' # Many helper programs mix const char* in char* variables
    disable_in_hostcflags 'inline' # Remove funny GCC warnings
    disable_in_hostcflags 'pointer-arith' # Linux does arithmetic on void pointers
    disable_in_hostcflags 'error=nested-externs'
    disable_in_hostcflags 'error=redundant-decls'
else
    echo >&2 "Unknown compiler $HOSTCC"
    exit 1
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
    echo 'CONFIG_RCU_CPU_STALL_TIMEOUT=21' >> "$KBUILD_OUTPUT/.config"

    # CEC_GPIO depends on PREEMPT, and selects CEC_PING, which enables CEC_PIN_ERROR_INJ
    echo 'CONFIG_CEC_GPIO=m' >> "$KBUILD_OUTPUT/.config"
    echo 'CONFIG_CEC_PIN_ERROR_INJ=y' >> "$KBUILD_OUTPUT/.config"
    # PREEMPTIRQ_EVENTS depends on DEBUG_PREEMPT
    echo 'CONFIG_PREEMPTIRQ_EVENTS=y' >> "$KBUILD_OUTPUT/.config"

    if $CC -v 2>&1 | grep -q clang
    then
        # Disable GCC plugins when using clang
        echo '# CONFIG_GCC_PLUGINS is not set' >> "$KBUILD_OUTPUT/.config"
        echo '# CONFIG_KCOV is not set' >> "$KBUILD_OUTPUT/.config"

        # Enable config that was not selected with KCOV_INSTRUMENT_ALL
        echo 'CONFIG_DRM_AMD_DC_DCN2_0=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DRM_AMD_DC_DCN2_1=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DRM_AMD_DC_DCN3_0=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DRM_AMD_DC_DSC_SUPPORT=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DRM_AMD_SECURE_DISPLAY=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_UBSAN_BOUNDS=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_UBSAN_LOCAL_BOUNDS=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_TEST_FPU=m' >> "$KBUILD_OUTPUT/.config"
    fi

    if [ "${BUILDCONF:-}" = 'xgcc-arm' ]
    then
        # Force compiling with ARMv7
        echo '# CONFIG_ARCH_MULTI_V6 is not set' >> "$KBUILD_OUTPUT/.config"
        echo '# CONFIG_ARCH_MULTI_V6_V7 is not set' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_ARM_LPAE=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_ARCH_AXXIA=y' >> "$KBUILD_OUTPUT/.config"
        echo '# CONFIG_THUMB2_KERNEL is not set' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_CXL_PMEM=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_KVM=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_TRANSPARENT_HUGEPAGE=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y' >> "$KBUILD_OUTPUT/.config"
        echo '# CONFIG_TRANSPARENT_HUGEPAGE_MADVISE is not set' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_READ_ONLY_THP_FOR_FS=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_VIRTIO_PMEM=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_NET_9P_XEN=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_BLKDEV_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_BLKDEV_BACKEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_SCSI_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_SCSI_BACKEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_PRIVCMD=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_NETDEV_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_NETDEV_BACKEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_INPUT_XEN_KBDDEV_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_HVC_XEN=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_HVC_XEN_FRONTEND=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_TCG_XEN=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_POWER_RESET_AXXIA=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_WDT=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DRM_XEN=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DRM_XEN_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_FBDEV_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_SND_XEN_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_BALLOON=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_SCRUB_PAGES_DEFAULT=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_DEV_EVTCHN=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_BACKEND=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XENFS=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_COMPAT_XENFS=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_SYS_HYPERVISOR=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_GNTDEV=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_GRANT_DEV_ALLOC=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_GRANT_DMA_ALLOC=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_PVCALLS_FRONTEND=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_PVCALLS_BACKEND=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_GNTDEV_DMABUF=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_LIBNVDIMM=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_BLK_DEV_PMEM=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_ND_BLK=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_BTT=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_OF_PMEM=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DEV_DAX=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_HUGETLBFS=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_CGROUP_HUGETLB=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_APPLE_DART=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_DMA_RESTRICTED_POOL=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_STACKPROTECTOR_PER_TASK=y' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_XEN_PCIDEV_STUB=m' >> "$KBUILD_OUTPUT/.config"
        echo 'CONFIG_USB_XEN_HCD=m' >> "$KBUILD_OUTPUT/.config"
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
