# Basic sanity check tests using the porcelain example programs

package require tcltest

namespace eval lg2::test {
    namespace path ::tcltest

    variable testDir [file normalize [file dirname [info script]]]

    variable oid_re {[[:xdigit:]]{40}}
}

if {[catch {
    package require lg2
}]} {
    lappend auto_path [file join $lg2::test::testDir .. lib]
    package require lg2
}

namespace eval lg2::test {

    variable dirStack

    proc pushd {dir} {
        variable dirStack
        lappend dirStack [pwd]
        cd $dir
    }
    proc popd {} {
        variable dirStack
        set dir [lindex $dirStack end]
        set dirStack [lrange $dirStack 0 end-1]
        cd $dir
    }
    proc git_exec {dir args} {
        pushd $dir
        try {
            return [exec {*}[auto_execok git] {*}$args]
        } finally {
            popd
        }
    }
    proc porcelain_exec {porcelain_name args} {
        variable testDir
        set script_path [file join $testDir .. lib examples git-$porcelain_name.tcl]
        exec [info nameofexecutable] $script_path {*}$args 2>@1
    }
    proc porcelain_exec_with_status {args} {
        # Assumes working directory is current directory
        set output [porcelain_exec {*}$args]
        append output \n---\n
        append output [exec {*}[auto_execok git] status]
        return $output
    }
    proc porcelain_exec_with_log {args} {
        # Assumes working directory is current directory
        set output [porcelain_exec {*}$args]
        append output \n---\n
        append output [exec {*}[auto_execok git] log]
        return $output
    }
    proc setup_empty_repo {testid} {
        set dir [makeDirectory $testid]
        porcelain_exec init $dir
        return $dir
    }
    proc setup_ro_repo {} {
        set dir [makeDirectory lg2-temp-testrepo]
        file delete -force $dir
        git_exec . clone resources/testrepo.git $dir 2>@1
        proc setup_ro_repo {} "return $dir"
        return $dir
    }
    proc setup_rw_repo {name} {
        set dir [makeDirectory $name]
        file delete -force $dir
        git_exec . clone resources/testrepo.git $dir 2>@1
        return $dir
    }
    proc test_help {porcelain_name} {
        set re "Usage:.*$porcelain_name.*--version.*--help"
        test ${porcelain_name}-help-0 "$porcelain_name --help" \
            -body [list porcelain_exec $porcelain_name --help] \
            -result $re -match regexp
    }
    proc test_version {porcelain_name} {
        test ${porcelain_name}-version-0 "$porcelain_name --version" \
            -body [list porcelain_exec $porcelain_name --version] \
            -result 0.1a0
    }

    ### init

    test_version init
    test_help init

    test init-0 {init git repository in current directory} -setup {
        set workdir [makeDirectory init-0]
        set curdir [pwd]
        cd $workdir
    } -cleanup {
        cd $curdir
    } -body {
        set text [porcelain_exec init .]
        append text \n---\n
        append text [git_exec $workdir status]
    } -result "^Initialized git repository at.*init-0.*---.*On branch master.*No commits yet.*nothing to commit" -match regexp

    test init-1 {init git repository in specified directory} -setup {
        set workdir [makeDirectory init-1]
    } -body {
        set text [porcelain_exec init $workdir]
        append text \n---\n
        append text [git_exec $workdir status]
    } -result "^Initialized git repository at.*init-1.*---.*On branch master.*No commits yet.*nothing to commit" -match regexp

    test init-bare-0 {init bare git repository} -setup {
        set workdir [makeDirectory init-bare-0]
    } -body {
        porcelain_exec init --bare $workdir
        list \
            [file exists [file join $workdir config]] \
            [file exists [file join $workdir description]] \
            [file exists [file join $workdir HEAD]] \
            [file isdirectory [file join $workdir objects]] \
            [file isdirectory [file join $workdir refs]]
    } -result {1 1 1 1 1}

    test init-initial-commit-0 {init git repository with initial commit} -setup {
        set workdir [makeDirectory init-initial-commit-0]
    } -body {
        set text [porcelain_exec init --initial-commit $workdir]
        append text \n---\n
        append text [git_exec $workdir status]
    } -result "^Initialized git repository at.*init-initial-commit-0.*Initial commit:.*---.*On branch master.*nothing to commit" -match regexp

    test init-quiet-0 {init git repository in current directory} -setup {
        set origdir [pwd]
        set workdir [makeDirectory init-quiet-0]
        cd $workdir
    } -cleanup {
        cd $origdir
    } -body {
        set text [porcelain_exec init --quiet .]
        append text \n---\n
        append text [git_exec $workdir status]
    } -result "^\\s*---.*On branch master.*No commits yet.*nothing to commit" -match regexp

    ### add

    test_version add
    test_help add

    test add-0 "Add a file" -setup {
        set testid add-0
        set workdir [setup_empty_repo $testid]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        makeFile "Test $testid" $testid.txt $workdir
        porcelain_exec_with_status add $testid.txt
    } -result "^\\s*---\n\\s*On branch master.*Changes to be committed:.*new file:\\s*add-0.txt" -match regexp

    test add-1 "Add a directory" -setup {
        set testid add-1
        set workdir [setup_empty_repo $testid]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        file mkdir sub
        makeFile "Test $testid - 1" 1.txt sub
        makeFile "Test $testid - 2" 2.txt sub
        porcelain_exec_with_status add sub
    } -result "^\\s*---\n\\s*On branch master.*Changes to be committed:.*new file:\\s*sub/1.txt\\s+new file:\\s*sub/2.txt" -match regexp

    test add-verbose-0 "Add a file" -setup {
        set testid add-verbose-0
        set workdir [setup_empty_repo $testid]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        makeFile "Test $testid" $testid.txt $workdir
        porcelain_exec_with_status add --verbose $testid.txt
    } -result "^add 'add-verbose-0.txt'\\s*---\n\\s*On branch master.*Changes to be committed:.*new file:\\s*add-verbose-0.txt" -match regexp

    test add-dry-run-0 "Add a file - dry run" -setup {
        set testid add-dry-run-0
        set workdir [setup_empty_repo $testid]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        makeFile "Test $testid" $testid.txt $workdir
        porcelain_exec_with_status add --dry-run $testid.txt
    } -result "^add 'add-dry-run-0.txt'\\s*---\n\\s*On branch master.*Untracked files:.*add-dry-run-0.txt.*nothing added to commit" -match regexp

    test add-git-dir-work-tree-0 "Add a file using --git-dir and --work-tree" -setup {
        set testid add-0
        set workdir [setup_empty_repo $testid]
    } -body {
        makeFile "Test $testid" $testid.txt $workdir
        set output [porcelain_exec add --work-tree $workdir --git-dir [file join $workdir .git] [file join $workdir $testid.txt]]
        pushd $workdir
        append output \n---\n
        append output [git_exec $workdir status]
        popd
        set output
    } -result "^\\s*---\n\\s*On branch master.*Changes to be committed:.*new file:\\s*add-0.txt" -match regexp

    ### commit

    test_help commit
    test_version commit

    test commit-0 "commit" -setup {
        set testid commit-0
        set workdir [setup_empty_repo $testid]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        makeFile "Test $testid" $testid.txt $workdir
        porcelain_exec add $testid.txt
        porcelain_exec_with_log commit
    } -result "^HEAD not found. Creating first commit.\\s*---\n\\s*commit \[\[:xdigit:]]{40}.*Author:.*Date:.*Commit" -match regexp

    test commit-message-0 "commit --message" -setup {
        set testid commit-message-0
        set workdir [setup_empty_repo $testid]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        makeFile "Test $testid" $testid.txt $workdir
        porcelain_exec add $testid.txt
        porcelain_exec_with_log commit -m "First commit"
    } -result "^HEAD not found. Creating first commit.\\s*---\n\\s*commit \[\[:xdigit:]]{40}.*Author:.*Date:.*First commit" -match regexp

    ### clone

    test_help clone
    test_version clone

    test clone-0 "clone https" -setup {
        set workdir [makeDirectory clone-0]
    } -body {
        porcelain_exec clone "https://github.com/libgit2/TestGitRepository.git" $workdir
        pushd $workdir
        set files [lsort [concat [glob *] [glob -types hidden *]]]
        popd
        set files
    } -result {.git a b c master.txt}

    ### tag

    test_help tag
    test_version tag

    test tag-list-0 "List tags" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        lsort [porcelain_exec tag]
    } -result {annotated_tag_to_blob e90810b hard_tag point_to_blob taggerless test wrapped_tag}

    test tag-list-1 "List tags" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        lsort [porcelain_exec tag --list]
    } -result {annotated_tag_to_blob e90810b hard_tag point_to_blob taggerless test wrapped_tag}

    test tag-0 "Tag create" -setup {
        set workdir [setup_rw_repo tag-0]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        porcelain_exec tag lg2-test-tag
        git_exec $workdir cat-file -t lg2-test-tag
    } -result "commit" -match regexp

    test tag-gitdir-worktree-0 "Tag --git-dir --work-tree" -setup {
        set workdir [setup_rw_repo tag-gitdir-worktree-0]
    } -body {
        porcelain_exec tag --git-dir [file join $workdir .git] --work-tree $workdir lg2-test-tag
        git_exec $workdir cat-file -t lg2-test-tag
    } -result "commit" -match regexp

    test tag-annotated-0 "Tag create annotated" -setup {
        set workdir [setup_rw_repo tag-annotated-0]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        porcelain_exec tag lg2-annotated-tag
        git_exec $workdir cat-file -t lg2-annotated-tag
    } -result "tag" -match regexp

    test tag-delete-0 "Delete tags" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        porcelain_exec tag -d test
        lsort [git_exec $workdir tag -l]
    } -result {annotated_tag_to_blob e90810b hard_tag point_to_blob taggerless wrapped_tag}

    ### log

    test_help log
    test_version log

    proc parse_log {text} {
        set log_records {}
        foreach line [split $text \n] {
            set line [string trim $line]
            if {$line eq ""} continue
            switch -glob -- $line {
                commit* {
                    if {[info exists rec]} {
                        dict append rec comment ""; # Ensure it exists
                        lappend log_records $rec
                        set rec {}
                    }
                    dict set rec commit [lindex [split $line " "] 1]
                }
                Author:* {
                    dict set rec author [string trim [string range $line 7 end]]
                }
                Date:* {
                    # git does not print leading 0's
                    set line [regsub -all { 0(\d+)} [string range $line 5 end] { \1}]
                    dict set rec date [string trim $line]
                }
                default {
                    dict append rec comment $line
                }
            }
        }
        if {[info exists rec] && [dict size $rec]} {
            dict append rec comment ""; # Ensure it exists
            lappend log_records $rec
        }
        return $log_records
    }

    proc compare_logs {loga logb} {
        foreach reca $loga recb $logb {
            if {[catch {
                set commita [dict get $reca commit]
                set commitb [dict get $recb commit]
            }]} {
                puts reca:$reca
                puts recb:$recb
                continue
            }
            if {$commita ne $commitb} {
                return "commit sequence mismatch ($commita, $commitb)"
            }
            foreach key {author date comment} {
                set vala [dict get $reca $key]
                set valb [dict get $recb $key]
                if {$vala ne $valb} {
                    return "Record for commit $commita differs in key $key.\n$vala != $valb"
                }
            }
        }
        return ""
    }
    
    test log-0 "log" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log]
        set plog [porcelain_exec log]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 7}

    test log-1 "log" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log]
        set plog [porcelain_exec log]
        compare_logs [parse_log $plog] [parse_log $glog]
    } -result {}

    test log-1 "log path" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log README]
        set plog [porcelain_exec log README]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 2}

    test log-reverse-0 "log reverse" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --reverse]
        set plog [porcelain_exec log --reverse]
        compare_logs [parse_log $plog] [parse_log $glog]
    } -result {}

    test log-date-order-0 "log date order" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --date-order]
        set plog [porcelain_exec log --date-order]
        compare_logs [parse_log $plog] [parse_log $glog]
    } -result {}

    test log-committer-0 "log -committer" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --committer Scott]
        set plog [porcelain_exec log --committer Scott]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [expr {[llength $parsed_log] > 0}]
    } -result [list {} 1]

    test log-committer-1 "log -committer (empty)" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --committer nosuch]
        set plog [porcelain_exec log --committer nosuch]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [expr {[llength $parsed_log] == 0}]
    } -result [list {} 1]

    test log-author-0 "log -author" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --author Scott]
        set plog [porcelain_exec log --author Scott]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [expr {[llength $parsed_log] > 0}]
    } -result [list {} 1]

    test log-author-1 "log -author (empty)" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --author nosuch]
        set plog [porcelain_exec log --author nosuch]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result [list {} 0]

    test log-grep-0 "log grep" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --grep branch]
        set plog [porcelain_exec log --grep branch]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 2}

    test log-skip-0 "log skip" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --skip 3]
        set plog [porcelain_exec log --skip 3]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 4}

    test log-max-count-0 "log max-count" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --max-count 3]
        set plog [porcelain_exec log --max-count 3]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 3}

    test log-merges-0 "log merges" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --merges]
        set plog [porcelain_exec log --merges]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 1}

    test log-min-parents-0 "log min-parents" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --min-parents=2]
        set plog [porcelain_exec log --min-parents=2]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 1}

    test log-max-parents-0 "log max-parents" -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --max-parents=1]
        set plog [porcelain_exec log --max-parents=1]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 6}

    # Disabled because not clear what git reports as log-size
    test log-log-size-0 "log log-size" -constraint {
        disabled
    } -setup {
        set workdir [setup_ro_repo]
        pushd $workdir
    } -cleanup {
        popd
    } -body {
        set glog [git_exec $workdir log --log-size]
        set plog [porcelain_exec log --log-size]
        set parsed_log [parse_log $plog]
        list [compare_logs $parsed_log [parse_log $glog]] [llength $parsed_log]
    } -result {{} 7}
}

::tcltest::cleanupTests
namespace delete lg2::test


