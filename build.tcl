#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}
set me [file normalize [info script]]
proc main {} {
    global argv
    if {![llength $argv]} { set argv help}
    if {[catch {
	eval _$argv
    }]} usage
    exit 0
}
set packages {
    {bfp bfp.tcl}
}
proc usage {{status 1}} {
    global errorInfo
    if {($errorInfo ne {}) &&
	![string match {invalid command name "_*"*} $errorInfo]
    } {
	puts stderr $::errorInfo
	exit
    }

    global argv0
    set prefix "Usage: "
    foreach c [lsort -dict [info commands _*]] {
	set c [string range $c 1 end]
	if {[catch {
	    H${c}
	} res]} {
	    puts stderr "$prefix$argv0 $c args...\n"
	} else {
	    puts stderr "$prefix$argv0 $c $res\n"
	}
	set prefix "       "
    }
    exit $status
}
proc +x {path} {
    catch { file attributes $path -permissions u+x }
    return
}
proc grep {file pattern} {
    set lines [split [read [set chan [open $file r]]] \n]
    close $chan
    return [lsearch -all -inline -glob $lines $pattern]
}
proc version {file} {
    set provisions [grep $file {*package provide*}]
    #puts /$provisions/
    return [lindex $provisions 0 3]
}
proc Hhelp {} { return "\n\tPrint this help" }
proc _help {} {
    usage 0
    return
}
proc Hrecipes {} { return "\n\tList all brew commands, without details." }
proc _recipes {} {
    set r {}
    foreach c [info commands _*] {
	lappend r [string range $c 1 end]
    }
    puts [lsort -dict $r]
    return
}
proc Hinstall {} { return "?destination?\n\tInstall all packages, and application.\n\tdestination = path of package directory, default \[info library\]." }
proc _install {{dst {}}} {
    global packages

    if {[llength [info level 0]] < 2} {
	set dstl [info library]
	set dsta [file dirname [file normalize [info nameofexecutable]]]
    } else {
	set dstl $dst
	set dsta [file dirname $dst]/bin
    }

    # Create directories, might not exist.
    file mkdir $dstl
    file mkdir $dsta

    foreach item $packages {
	# Package: /name/

	if {[llength $item] == 3} {
	    foreach {dir vfile name} $item break
	} elseif {[llength $item] == 1} {
	    set dir   $item
	    set vfile {}
	    set name  $item
	} else {
	    foreach {dir vfile} $item break
	    set name $dir
	}

	if {$vfile ne {}} {
	    set version  [version [file dirname $::me]/lib/$dir/$vfile]
	} else {
	    set version {}
	}

	file copy   -force [file dirname $::me]/lib/$dir     $dstl/${name}-new
	file delete -force $dstl/$name$version
	file rename        $dstl/${name}-new     $dstl/$name$version
	puts "Installed package:     $dstl/$name$version"
    }

    # Applications: bookflow components.

    foreach f [glob -directory [file dirname $::me]/bin *] {
	set fx [file tail $f]
	file copy $f $dsta
	+x $dsta/$fx
	puts "Installed application: $dsta/$fx"
    }

    return
}
proc Huninstall {} { return "?destination?\n\tRemove all packages, and application.\n\tdestination = path of package directory, default \[info library\]." }
proc _uninstall {{dst {}}} {
    global packages

    if {[llength [info level 0]] < 2} {
	set dstl [info library]
	set dsta [file dirname [file normalize [info nameofexecutable]]]
    } else {
	set dstl $dst
	set dsta [file dirname $dst]/bin
    }

    foreach item $packages {
	# Package: /name/

	if {[llength $item] == 3} {
	    foreach {dir vfile name} $item break
	} elseif {[llength $item] == 1} {
	    set dir   $item
	    set vfile {}
	    set name  $item
	} else {
	    foreach {dir vfile} $item break
	    set name $dir
	}

	if {$vfile ne {}} {
	    set version  [version [file dirname $::me]/lib/$dir/$vfile]
	} else {
	    set version {}
	}

	file delete -force $dstl/$name$version
	puts "Removed package:     $dstl/$name$version"
    }

    # Applications: bookflow components.

    foreach f [glob -directory [file dirname $::me]/bin *] {
	set fx [file tail $f]
	file delete $dsta/$fx
	puts "Removed application: $dsta/$fx"
    }
    return
}
main
