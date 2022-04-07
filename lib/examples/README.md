This directory contains demo versions of the git "porcelain" commands - the 
higher level commands that are generally used at the command level. The code
is based on the [examples](https://github.com/libgit2/libgit2/tree/main/examples)
in the `libgit2` repository.

The scripts are intended to be invoked from the shell, e.g.

```
tclsh git-init.tcl ~/repo
```

Specify the `--help` command line option with each script for a usage summary.
The available options correspond approximately, not completely, to those of the
"official" git implementation.

The `libgit` examples directory linked above has additional examples that you
can use as a model.
