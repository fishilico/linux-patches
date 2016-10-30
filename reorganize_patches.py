#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright (c) 2015-2016 Nicolas Iooss
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
"""Reorganize patches in several directories

The aim is to make tracking changes to patches easier than plain numbered
patches in one directory (e.g. when a patch got merged upstream, every later
patches got their index decreased).

This script does NOT change the content of patches in any way.

@author: Nicolas Iooss
@license: MIT
"""
import argparse
import re
import os
import os.path
import sys


def get_patch_path(patchdir, name):
    """Get the canonical path to the give file patch"""
    directory = ''

    # Get the subject line
    subject = None
    with open(os.path.join(patchdir, name), 'r') as fpatch:
        for line in fpatch:
            matches = re.match(r'Subject: \[PATCH\] (.*)', line.rstrip())
            if matches is not None:
                subject = matches.group(1)
            if line.startswith('Sent-upstream:'):
                directory = 'sent-upstream'
    if subject is None:
        sys.stderr.write("Error: unable to read the subject of patch {}\n"
                         .format(name))
        return None

    # Find a suitable directory, for the topic of the patch
    KNOWN_TOPICS = {
        '{CONSTIFY}': 'constify',
        '{For LLVMLinux}': 'llvmlinux',
        '{LLVMLinux}': 'llvmlinux',
        '{MAYBE UPS}': 'maybe_upstreamable',
        '{NOT UPSTREAMABLE}': 'not_upstreamble',
        '{PLUGIN}': 'plugin',
        '{PRAGMA}': 'pragma',
        '{PRINTF}': 'printf',
        '{REJECTED}': 'rejected',
        '{SENT}': 'sent-upstream',
        '{TYPO}': 'typo',
    }
    for topic, topicdir in KNOWN_TOPICS.items():
        if subject.startswith(topic + ' '):
            directory = topicdir
            subject = subject[len(topic) + 1:]
            break

    # Canonicalize the subject into a patch name
    name = re.sub(r'[^._0-9a-zA-Z]', '-', subject).strip('-')
    name = re.sub(r'--+', '-', name)

    # "BUG" tags have more diversity
    if subject.startswith('{BUG') and name.startswith('BUG-'):
        directory = 'bug'
        name = name[4:]

    if not directory:
        sys.stderr.write("Warning: patch {} has no specific directory\n"
                         .format(name))

    return os.path.join(directory, name) + '.patch'

def reorganize_patches(patchdir):
    """Reorganize the patches in the given directory"""
    # Read the series file
    series_file = os.path.join(patchdir, 'series')
    with open(series_file, 'r') as fseries:
        series = [line.strip() for line in fseries.readlines()]

    # Find new names from the patch content
    new_series = [get_patch_path(patchdir, name) for name in series]
    if None in new_series:
        return False

    # Sanity checks on new patch names
    new_to_old = {}
    for old, new in zip(series, new_series):
        # Check that there are no duplicates in new_series
        if new in new_to_old:
            sys.stderr.write("Error: patches {} and {} renamed to {}.\n"
                             .format(new_to_old[new], old, new))
            return False
        new_to_old[new] = old
        if old == new:
            continue
        # Check that new does not exist in the filesystem
        new = os.path.join(patchdir, new)
        if os.path.exists(new):
            sys.stderr.write("Error: {} already exists.\n".format(new))
            return Fase

    # Create a new series file
    new_series_file = series_file + '.new'
    with open(new_series_file, 'w') as fseries:
        fseries.write('\n'.join(new_series) + '\n')

    # Move the files
    for old, new in zip(series, new_series):
        if old != new:
            print("{} -> {}".format(old, new))
            old = os.path.join(patchdir, old)
            new = os.path.join(patchdir, new)
            os.renames(old, new)
    os.rename(new_series_file, series_file)
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description="Reorganize patches")
    parser.add_argument('patchdir', metavar='PATCHDIR', nargs=1,
                        help="patch directory to reorganize")
    args = parser.parse_args(argv)

    return 0 if reorganize_patches(args.patchdir[0]) else 1

if __name__ == '__main__':
    sys.exit(main())
