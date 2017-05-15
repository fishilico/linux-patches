#!/bin/sh
#
# Copyright (c) 2016-2017 Nicolas Iooss
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
# Commit modifications to patches/ directory

cd "$(dirname -- "$0")" || exit $?

VERSION="$(git -C linux describe "$(cat patches/upstream-commit.hash)")"

# Remove leading "v"
VERSION="${VERSION#v}"

# Compute the expected RC version in tracked-patches.txt
case "$VERSION" in
    *.*-rc*)
        # 4.2-rc10-... => 4.2
        EXPECTED_RCVER="${VERSION%%-rc*}"
        ;;
    *.*-*)
        # 4.2-... => 4.3
        FULLVER="${VERSION%%-*}"
        MAJVER="${FULLVER%.*}"
        MINVER="${FULLVER##*.}"
        EXPECTED_RCVER="$MAJVER.$((MINVER + 1))"
        ;;
    *)
        # 4.2, no RC
        EXPECTED_RCVER=''
        ;;
esac
# Sanity check: no "For current rc" in tracked-patches.txt when committing releases
CURRENT_RCVER="$(sed -n 's/^For current rc (Linux \(.*\))$/\1/p' tracked-patches.txt)"
if [ "$CURRENT_RCVER" != "$EXPECTED_RCVER" ] ; then
    if [ -z "$EXPECTED_RCVER" ] ; then
        echo >&2 'Error: tracked-patches.txt uses current-rc patches for a full release!'
    else
        echo >&2 'Error: tracked-patches.txt does not define a current RC'
    fi
    exit 1
fi

if [ -z "$CURRENT_RCVER" ] ; then
    echo "Commit from full version $VERSION"
else
    echo "Commit for RC version $CURRENT_RCVER with base $VERSION"
fi

# Force GPG signing
if [ "$(git config commit.gpgsign)" != true ] ; then
    git config commit.gpgsign true
fi

set -x -e
git reset HEAD
git add patches tracked-patches.txt
git commit -m "Linux $VERSION"
