#  `lg2` - Tcl/CFFI binding to libgit2

The `lg2` package is a binding to the [libgit2](https://libgit2.org) library. It
is only intended as a demonstration of using CFFI to wrap a fairly substantial
shared library (more than 800 functions) and thus lacks a comprehensive test suite
though some basic sanity checks are in the tests directory. Use in
production will require client applications to write their own.

The source repository is at https://github.com/apnadkarni/tcl-libgit2.

The package distribution is available from
https://sourceforge.net/projects/magicsplat/files/lg2/.

## Porcelain and plumbing

The commands in official git implementation can be divided into two categories:

* The *plumbing* commands like `hash-object`, `write-tree` etc.
which implement the low level operations.

* The *porcelain* commands, like `git-clone`, `git-commit` etc. that are invoked
by the user in daily usage and are built on top of the plumbing commands.

The `libgit2` API implements the equivalent of the plumbing commands and
accordingly so does the `lg2` package. Be warned that using the package requires
understanding the `libgit2` API which in turn requires understanding git and its
internal structures. The `examples` directory contains implementations of
simpler versions of the high level `git` porcelain commands that illustrate the
use of the plumbing commands and can be used as a starting point for more
complete implementations.

## Prerequisites

The `lg2` package has two prerequisites.

* The Tcl [`cffi`](https://cffi.magicsplat.com) extension, version 1.0b5 or
later, must be present somewhere in the Tcl package search path.

* The [`libgit2`](https://libgit2.org] shared library, either v1.3 or v1.4.

See later sections about obtaining these.

## Usage

Install the distribution into a directory present in Tcl's `auto_path` variable.

To use the `lg2` package, it must be loaded and then initialized with the
path to the `libgit2` shared library. For example,

```
package require lg2
lg2::lg2_init /lib/x86_64-linux-gnu/libgit2.so
```

If no path is supplied to `lg2_init` it will try to locate `libgit2.dll` or
`git2.dll` on Windows and `libgit2.so` on other platforms under
architecture-specific directories under the package directory. If not found
there, it will just attempt to load using the unqualified shared library name
assuming the library is present in a standard system directory.

The scripts in the `examples` directory are standalone scripts that
mimic the porcelain git commands. All support the `--help` option to 
display some basic help on syntax and options. For example,

```
> tclsh git-init.tcl --help
Usage: tclsh.exe git-init.tcl [OPTION]... DIRECTORY

Demo of cffi libgit extension. Poor man's git init emulation from libgit2
Translated to Tcl from libgit2/examples/init.c

Mandatory arguments to long options are also mandatory for short options.
  -q, --quiet               Only print error and warning messages;
                            all other output will be suppressed.
      --bare                Create a bare repository.
      --initial-commit      Create an empty initial commit
      --shared=PERMS        Set the sharing permissions. PERMS should be
                            "umask" (default), "group", "all" or an
                            integer umask value.
      --template=DIRECTORY  Uses the templates from DIRECTORY.
      --help                display this help and exit
```

## Command reference

There is no separate documentation for the `lg2` package commands as it (almost)
directly maps the `libgit2` API into Tcl. The following `libgit2` links
serve as documentation. **Make sure you use the libgit2 documentation for
the appropriate version**.


* [API reference](https://libgit2.org/libgit2/)
* [Libgit2 snippets](https://libgit2.org/docs/guides/101-samples/)

A few differences in useage from the `libgit2` C API are listed below. Also, the
samples in the `examples` directory may be useful as a tutorial for command
usage.

* All commands are placed in the `lg2` namespace.

* `libgit2` prefixes all its functions with `git_`. The `lg2` package adds a few
utility commands. These are prefixed with `lg2_`. It is thus safe to put the
`lg2` namespace in the application namespace path as they are unlikely to clash
with commands from other packages.

* Most `libgit2` functions return an error code on failure. The corresponding
wrapped Tcl commands raise a Tcl exception instead with the error message
retrieved from `libgit2`.

* Since `libgit2` uses function return values to indicate success and failure,
it returns the actual function result through an output parameter. Because the
wrapped commands use Tcl's exception mechanism, the command result is not needed
to indicate success or failure. The commands thus return the output parameter
value as the command result.

* Handling of `git_strarray` structs can be slightly tricky because the internal
buffers may be allocated by `libgit2` or the application. Thus a "shadow" struct
`lg2_strarray` is defined to distinguish the two use cases. See the comments
in `strarray.tcl` more information and some utility commands to deal with these.

* Along similar lines, the `git_signature` structure may be returned by a
`libgit2` function. The `lg2` package defines the script level struct of
the same name. Now a pointer to a `git_signature` may come either from
`libgit2` function or by from the CFFI allocating commands
`git_signature allocate` or `git_signature new`. It is **crucial** that
the former is freed by a call to the `libgit2` (wrapped) function
`git_signature_free` while the latter must be freed through the
`git_signature free` (note one is a wrapped function, other is a call to
the `free` method for the CFFI `git_signature` struct command instance).

* `libgit2` uses utf-8 string encoding by default. Correspondingly, `lg2`
defines the `STRING` CFFI alias that is used by most declarations. Some commands
allow for strings in arbitrary encodings. These have to be passed as encoded
binary strings with the encoding name in a separate parameter. The encoding
names are from IANA, not those used by Tcl's `encoding` command. The package
therefore provides some utility commands `lg2_encoding convertto` and
`lg2_encoding convertfrom` to help with such conversions. They work like Tcl's
`encoding` equivalents except they accept the encoding names used by `libgit2`
instead of Tcl encoding names.

* One note to keep in mind with `libgit2` (this is independent of the `lg2` package)
is that many functions that take file paths as arguments expect `/` to be used as
the path separator and will not work correctly with `\`. Moreover, some expect
paths to be relative to top of the working directory.

All of the above are illustrated by the samples in the `examples` directory.

## Obtaining the `cffi` extension

The documentation for the `cffi` Tcl extension is at https://cffi.magicsplat.com.
Binaries for some platforms and source distributions are downloadable from
https://sourceforge.net/projects/magicsplat/files/cffi. To build from source,
see the file `BUILD.md` in the distribution.

## Obtaining the `libgit2` library

The `lg2` distribution includes `libgit2` DLL's for Windows platforms. See
instructions below to build the DLL's yourself.

On most Unix/Linux systems `libgit2` can be installed using the system's package
manager. However, system provided `libgit2` packages are often out of date.
Currently the `lg2` package supports `libgit2` versions 1.3 and 1.4. If the
system package manager does not include `libgit2` or includes a different
version, see build instruction below.

**Important:** Only use supported **release* versions of `libgit2` as it does
not guarantee ABI compatibility even between minor releases. Moreover, binaries built
from repository sources may not work even if version numbers are the same since
structures may change between releases. 

### Building using `vcpkg`

On systems supported by [vcpkg](https://github.com/microsoft/vcpkg/)
(Windows, Linux, MacOS), it may be used to build `libgit2`. For example,
on Windows, to build `libgit2` with `ssh` support,

```
vcpkg install "libssh2[zlib]" --triplet x64-windows --recurse
vcpkg install "libgit2[core,ssh]" --triplet x64-windows --recurse
```

Note to load `libgit2`, its dependencies like `libssh2`, `zlib`, `libcrypto`
etc. must also be on the path. The `vcpkg` commands will automatically download
and build these as required.

### Building `libgit2` from source

You may need to build `libgit2` from source if binaries are not available
by one of the previous mentioned means or if you wish for a standalone
`libgit2` shared library with all dependencies statically bound.

*Note: the instructions below pertain to `libgit2` version 1.4.2. Other versions
may need some tweaks as the build system has some differences between versions.

The sources for `libgit2` can be downloaded from
the [repository](https://github.com/libgit2/libgit2/releases). Make sure to
only download an official release, not a repository snapshot.
Instructions for building `libgit2` are given in the `README.md` file in the
`libgit2` sources. Below are some examples and workarounds for some potential
issues.

The `cmake` program is required to do builds.

#### Building on Unix-like systems

On Unix-like systems, first ensure the `zlib` and `libssh2` libraries are
installed using the system's package manager. Then execute the following from a
shell in the top-level `libgit2` source directory to build the shared library
and run the test suite.

```
cmake -S . -B build/ubuntu -DCMAKE_BUILD_TYPE=Release -DDEPRECATE_HARD=ON -DUSE_SSH=ON
cmake --build build/ubuntu
cd build/ubuntu
./libgit2_tests
```

#### Building on Windows

On Windows, the `libgit2` DLL may be build with either the MinGW/GCC tool chain
or Visual Studio.

#### Building with MinGW-W64

The corresponding steps for Windows given below are a little more involved
because (a) dependencies need to be installed and (b) as a preference, the build
is configured to **statically** link the dependencies into the `libgit2` DLL so no
additional DLLs need to be distributed.

To build with MinGW-W64/gcc, commands below must be run from a MING64 shell
(**not** the MSYS shell).

First install the dependencies using `pacboy` (or the `pacman` equivalents)

```
pacboy sync libssh2-wincng
```

**Note** The `libssh2` package may be installed in lieu of `libssh2-wincng`.
However, that requires the additional openssl libraries while `libssh2-wincng`
uses native Win32 crypto functions and is preferred for that reason.

Then run the following in the MINGW64 shell to build and test.

```
cmake -S . -B build/mingw64 -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DDEPRECATE_HARD=ON -DUSE_SSH=ON -DCMAKE_C_STANDARD_LIBRARIES="-lbcrypt -lcrypt32 -lws2_32" -DLIBSSH2_LIBRARIES=libssh2.a -DUSE_BUNDLED_ZLIB=ON -DHAVE_LIBSSH2_MEMORY_CREDENTIALS=1
cmake --build build/mingw64
cd build/mingw64
./libgit2_tests
```

Note the options used:

* `-DLIBSSH2_LIBRARIES=libssh2.a` forces static linking to `libssh2`
* `-DUSE_BUNDLED_ZIP=ON` uses the zlib library within `libgit2` and eliminate
the external dependency
* The `CMAKE_C_STANDARD_LIBRARIES` and `HAVE_LIBSSH2_MEMORY_CREDENTIALS` work
around some configuration bugs in `libgit2` that manifest themselves with static
linking.

Building a 32-bit version is similar except that the commands must be run
in the `MINGW32` shell and not in the `MINGW64` one.

```
cmake -S . -B build/mingw32 -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DDEPRECATE_HARD=ON -DUSE_SSH=ON -DCMAKE_C_STANDARD_LIBRARIES="-lbcrypt -lcrypt32 -lws2_32" -DLIBSSH2_LIBRARIES=libssh2.a -DUSE_BUNDLED_ZLIB=ON -DHAVE_LIBSSH2_MEMORY_CREDENTIALS=1
cmake --build build/mingw32
cd build/mingw32
./libgit2_tests
```

#### Building with Visual Studio

Since there is no bundled `libssh2` with Visual Studio, download its 
[source distribution](https://github.com/libssh2/libssh2/releases) and extract it
to a local directory. No need to build it.

*Important* Comment the line `include(SelectSSH)` in src/CMakeLists.txt in the
`libgit2` distribution. See [Bug 6254](https://github.com/libgit2/libgit2/issues/6254).

Then from a Visual Studio 64-bit prompt, run the following commands in the top
level directory of the `libgit2` source distribution.

```
cmake -S . -B build\vs64 -A x64 -DEMBED_SSH_PATH="D:/src/AAThirdparty/C,C++/libssh2-1.10.0" -DUSE_BUNDLED_ZLIB=ON -DDEPRECATE_HARD=ON
cmake --build build/vs64 --config Release
cd build\vs64
libgit2_tests
```

**NOTE:** Use forward slashes in -D definitions even for Visual Studio builds.

If your directory is not on the C: drive, you may see a few test failures.

The 32-bit build is similar except that you need to run the commands from a Visual
Studio 32-bit prompt and the `-A` option should be left out or take the value 
`Win32` instead of `x64`.

## Support

I can only (attempt to) answer questions related to the use of CFFI in this package.
For questions about `libgit2` itself, see one of

* The [libgit2 documentation](https://libgit2.org)

* The [github discussions](https://github.com/libgit2/libgit2/discussions) section

* The [stackoverflow group](https://stackoverflow.com/questions/tagged/libgit2)
