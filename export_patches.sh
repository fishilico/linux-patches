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
# Export git commit to patch files

cd "$(dirname -- "$0")" || exit $?

if ! [ -d linux ] ; then
    echo >&2 "Error: linux/ directory is missing"
    exit 1
fi

# Find the base git commit for the patchs
FIRST_CUSTOM_COMMIT="$(git -C linux log --format=%H origin/master..master |tail -n1)"
if [ $? != 0 ] || [ -z "$FIRST_CUSTOM_COMMIT" ] ; then
    echo >&2 "Unable to find the first custom git commit"
    exit 1
fi
BASE_COMMIT="$(git -C linux rev-parse "$FIRST_CUSTOM_COMMIT^")"
if [ $? != 0 ] || [ -z "$BASE_COMMIT" ] ; then
    echo >&2 "Unable to find the base git commit"
    exit 1
fi
echo "Exporting patches from base $BASE_COMMIT"

# Create a new temporary dir for exports
PATCHDIR="$(mktemp -d export-patches-XXXXXXXXXX)"
trap 'if test -d "$PATCHDIR" ; then rm -r "$PATCHDIR" ; fi' EXIT HUP INT QUIT TERM

# Export patches
git -C linux format-patch --no-numbered -o "../$PATCHDIR" "$BASE_COMMIT..master" > "$PATCHDIR/raw_series" || exit $?
sed -e 's,\.\./[^/]\+/,,' "$PATCHDIR/raw_series" > "$PATCHDIR/series" || exit $?
echo "$BASE_COMMIT" > "$PATCHDIR/upstream-commit.hash" || exit $?
rm "$PATCHDIR/raw_series"

# Make the git patches reproductible:
# * Remove the commit ID
sed -i -e '1s/\(From\) [0-9a-f]\{40\} \(Mon Sep 17 00:00:00 2001\)/\1 0000000000000000000000000000000000000000 \2/' "$PATCHDIR/"*.patch
# * Remove the git version and the empty lines that are at the end of the files
sed -i -e '$,/^$/d' "$PATCHDIR/"*.patch
sed -i -e '$,/^[0-9.]*$/d' "$PATCHDIR/"*.patch

# Reorganise them
./reorganize_patches.py "$PATCHDIR" > /dev/null || exit $?

# Overwrite patches/ directory
rm -rf patches || exit $?
mv "$PATCHDIR" patches || exit $?

echo "Git commits have successfully been exported to patches/ directory."
