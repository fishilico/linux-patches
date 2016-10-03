#!/bin/sh
#
# Copyright (c) 2016 Nicolas Iooss
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
# Get the GitWeb interface of the maintainer of a file
# The aim is to quickly get access to the most recent changes not yet in Linus tree

# Keep get_maintainer.pl exit code if it fails
set -o pipefail

"$(dirname -- "$0")/linux/scripts/get_maintainer.pl" --scm --web "$@" | \
while IFS= read -r LINE
do
    # Filter the lines by type
    case "$LINE" in
        git\ *)
            # Replace Torvalds URL by linux-next, which is more useful for this program
            LINUS='git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git'
            NEXT='git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git'
            GIT="$(echo "${LINE#git }" | sed -e "s;$LINUS;$NEXT;" \
                -e 's;git://git.kernel.org/pub/scm/;https://git.kernel.org/cgit/;' \
                -e 's;git://anongit.freedesktop.org/;https://cgit.freedesktop.org/;' \
                -e 's;git://people.freedesktop.org/;https://cgit.freedesktop.org/;' \
                -e 's;git://linuxtv.org/;https://git.linuxtv.org/;')"
            BRANCH=''
            if [ "${GIT#http* }" != "$GIT" ]
            then
                BRANCH="${GIT#* }"
                GIT="${GIT%% *}"
            fi
            # Add path to the interesting file, if the argument is a path
            if [ $# -eq 1 ] && [ "${1#*/}" != "$1" ]
            then
                GIT="$GIT/tree/$1"
                if [ -n "$BRANCH" ]
                then
                    GIT="$GIT?h=$BRANCH"
                fi
            elif [ -n "$BRANCH" ]
            then
                GIT="$GIT?h=$BRANCH"
            fi
            echo "  git: $GIT"
            ;;
        http*)
            echo "  web: $LINE"
            ;;
        *@*)
            echo "email: $LINE"
            ;;
        *)
            echo "UNKNOWN $LINE"
            ;;
    esac
done
exit $?
