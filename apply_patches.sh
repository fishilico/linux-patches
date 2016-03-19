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
# Clone Linux git repository in linux/ and apply the patches in patches/

cd "$(dirname -- "$0")" || exit $?

if ! [ -d linux ] ; then
    # Clone the git repository using GitHub mirrors
    git clone --depth=100000 --branch master 'git://github.com/torvalds/linux.git' linux || exit $?
fi

# Find the commit ID
UPSTREAM_COMMIT="$(cat patches/upstream-commit.hash)"
if [ $? != 0 ] || [ -z "$UPSTREAM_COMMIT" ] ; then
    echo >&2 "Unable to read upstream git commit hash"
    exit 1
fi

# Grab the commit
if ! git -C linux show "$UPSTREAM_COMMIT" > /dev/null 2>&1 ; then
    echo "Unable to find commit $UPSTREAM_COMMIT in linux/, updating the repository."
    git -C linux fetch origin || exit 1
fi
if ! git -C linux show "$UPSTREAM_COMMIT" > /dev/null 2>&1 ; then
    echo >&2 "Unable to find commit $UPSTREAM_COMMIT in linux/!"
    exit 1
fi

# Create a new temporary "applying-patches" branch
git -C linux checkout -B applying-patches "$UPSTREAM_COMMIT" || exit $?

# Apply every patch
while IFS= read -r PATCHFILE ; do
    git -C linux am "../patches/$PATCHFILE" || exit $?
done < patches/series

# At the end, change to master branch
git -C linux checkout -B master applying-patches || exit $?
git -C linux branch -d applying-patches || exit $?

echo "Branch master is ready."
