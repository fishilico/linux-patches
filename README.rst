Some patches to GNU/Linux kernel
================================

Here are some patches to GNU/Linux which aims to:

* Fix some bugs in the kernel.
* Make it possible to compile the kernel with many compiler warnings flags, because several compiler warnings are useful but can't be used in vanilla kernel code because of "false-positives". The compiler-flag configuration is in ``make_allmodconfig.sh`` script.
* Enable using clang to compile the kernel, which reports different warnings from gcc, by using LLVMLinux patches (http://llvm.linuxfoundation.org/index.php/Main_Page). NB: according to https://github.com/ClangBuiltLinux/linux/issues/219 LLVMLinux seems to be now deprecated. A list of issues of building Linux with clang is available at https://github.com/ClangBuiltLinux/linux/issues.

How to build a kernel with these patches?
-----------------------------------------

Short answer, in a terminal::

    ./apply_patches.sh && ./make_allmodconfig.sh "-j$(nproc)"

This command line will clone GNU/Linux git repository, apply patches and build a kernel with clang using a parallel build.


In order to explain what each script does, here is a workflow when updating the patches with a more recent version of GNU/Linux:

* ``./apply_patches.sh`` : clone GNU/Linux git repository in ``linux/`` and apply patches from ``patches/`` directory
* ``cd linux && git fetch origin && git rebase origin/master`` : update GNU/Linux to latest master branch and rebase the patches on top of it
* ``JOBS="$(nproc)" ./test_make_gcc_clang.sh`` : compile the GNU/Linux once with gcc, then with clang, and if both succeed, record the output in a file named ``make.log_clang_YYY-MM-DD`` (with the current date).

    * If there were errors during the build, fix them in new patches and build again
    * It is possible to use ``make_allmodconfig.sh`` script to make debugging some issues easier. All parameters given to this script are transmitted to the underlying ``make`` command::

        # Build files in kernel/ directory using gcc
        HOSTCC=gcc CC=gcc ./make_allmodconfig.sh kernel/

        # Build init/main.o using clang (which is the default compiler)
        HOSTCC=clang CC=clang ./make_allmodconfig.sh init/main.o

* ``./export_patches.sh`` : export the patches back to ``patches/`` directory, using ``reorganize_patches.py`` to organize them in sub-directories.


How are the patches organized?
------------------------------

All the patches lies in subdirectories inside ``patches/``:

* ``patches/bug/`` patches fix some bugs which make the compiling fail.
* ``patches/constify/`` patches add ``const`` keyword in some places.
* ``patches/frama-c/`` patches modify the kernel so that Frama-C can be used.
* ``patches/llvmlinux/`` patches are related to clang compatibility (c.f. http://llvm.linuxfoundation.org/ ).
* ``patches/maybe_upstreamable/`` patches have a very low priority of being sent upstream.
* ``patches/not_upstreamble/`` patches have no chance to go upstream (they do not comply with coding rules, introduce dirty code, etc.).
* ``patches/plugin/`` patches implement some GCC plugins to analyze the code at compile time.
* ``patches/pragma/`` patches introduce ``#pragma`` statement, mostly to ignore warnings when it is expected.
* ``patches/printf/`` patches add ``__printf`` attribute to printf-like functions so that potential format string vulnerabilities are detected at build time.
* ``patches/rejected/`` patches were rejected (sometimes silently) by kernel developers.
* ``patches/sent-upstream/`` patches have already been sent upstream even though they were not yet applied.
* ``patches/typo/`` patches fix typos which are sprinkled all around in the kernel.

Moreover there are two important files to apply the patches:

* ``patches/series`` define the order used to apply the patches
* ``patches/upstream-commit.hash`` contains the GNU/Linux commit ID which is used as the base to apply the patches on.


Upstreamed patches
------------------

Patches are occasionally sent upstream. Here are some which got successfully applied:

* https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=c680e41b3a2e944185c74bf60531e3d316d3ecc4
  "eventpoll: fix uninitialized variable in epoll_ctl"
* https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=ea6edfbcefec1fcfdb826a1d5a054f402dfbfb24
  "mac802154: fix typo in header guard"
* https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=d43698e8abb58a6ac47d16e0f47bb55f452e4fc4
  "firmware/ihex2fw.c: restore missing default in switch statement"
* https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=5202efe544c279be152f44f2821010ff7b2d7e5b
  "coredump: use from_kuid/kgid when formatting corename"
* https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=3958b79266b14729edd61daf9dfb84de45f4ec6d
  "configfs: fix kernel infoleak through user-controlled format string"
* https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=0fd64291031d3587753b8adc53123b277855c777
  "drm/amdgpu: increment queue when iterating on this variable."

Other upstreamed patches can be found using for example
https://github.com/torvalds/linux/commits/master?author=fishilico
