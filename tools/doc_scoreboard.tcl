#!/bin/sh
# -*- tcl -*- \
exec tclsh "\$0" ${1+"$@"}
# tools
# - scan the bookflow sources for scoreboard access and generate
#   a database telling us who accesses what and how.

# ## ### ##### ######## ############# #####################

package require Tcl 8.5
package require fileutil

# ## ### ##### ######## ############# #####################

proc main {tooldir} {
    dump [sbscan [file dirname $tooldir]]
    return
}

proc sbscan {topdir} {
    puts Scanning\ $topdir...

    set db {}
    foreach f [fileutil::findByPattern $topdir -glob -- *.tcl] {
	if {[file isdirectory $f]} continue
	if {[string match *doc_scoreboard* $f]} continue
	if {[string match *pkgIndex* $f]} continue
	lappend db {*}[scansbfile $f [fileutil::stripPath $topdir $f]]
    }
    return $db
}

proc scansbfile {f fname} {
    puts \t$f...

    array set t {}

    foreach line [split [fileutil::cat $f] \n] {
	set line [string trim $line]
	switch -glob -- $line {
	    \#* {
		# ... pragmas
	    }
	    package*provide* {
		# might use this in future.
		# for new we key on the file name.
		lassign $line _ _ package _
	    }
	    scoreboard* {
		#puts \t\t|$line|
		word line ; # scoreboard
		set method [word line]
		switch -exact -- $method {
		    put {
			# remainder = tuples
			while {$line ne {}} {
			    lappend t([word line]) $method
			}
		    }
		    take -
		    takeall -
		    peek -
		    wpeek {
			lappend t([word line]) $method
		    }
		    unbind -
		    bind {
			set event [word line]
			lappend t([word line]) [list $method $event]
		    }
		    default {
			# unknown method.
			puts \tUnknown\ method \"$method\" found
		    }
		}
	    }
	}
    }

    if {![array size t]} { return }

    return [list $fname [array get t]]
}

proc word {svar} {
    upvar 1 $svar string
    set string [string trim $string]

    #puts "\[word \"$string\"\]"

    if {[string match "\$\{*" $string]} {
	set c varb
	regexp {(\${[^\}]+})[ 	]+(.*)$} $string -> word remainder
    } elseif {[string match "\$*" $string]} {
	set c var

	expr {[regexp {(\$[^ 	]+)[ 	]+(.*)$} $string -> word remainder] ||
	      [regexp {(\$[^ 	]+)()$} $string -> word remainder]}
    } elseif {[string match "\\\[*" $string]} {
	set c cmd
	set patterni "(\\\[\[^\]\]+\\\])\[ 	\]+(.*)$"
	set patterne "(\\\[\[^\]\]+\\\])()$"
	expr {[regexp $patterni $string -> word remainder] ||
	      [regexp $patterne $string -> word remainder]}
    } elseif {[string match "\\\{*" $string]} {
	set c w
	set patterni "(\\\{\[^\}\]+\\\})\[ 	\]+(.*)$"
	set patterne "(\\\{\[^\}\]+\\\})()$"
	expr {[regexp $patterni $string -> word remainder] ||
	      [regexp $patterne $string -> word remainder]}
    } else {
	set c w
	regexp {([^ 	]+)[ 	]+(.*)$} $string -> word remainder
    }

    if {![info exists word]} {
	error "word error ($string)"
    }

    #puts \t$c|$word|$remainder|

    set string $remainder
    return $word
}

proc dump {db} {
    array set d $db
    parray d

    set D {}
    foreach {fname ta} $db {
	foreach {tuple actions} $ta {
	    foreach a $actions {
		dict lappend D $tuple $a $fname
	    }
	}
    }

    array set T $D
    parray T
    return
}

# ## ### ##### ######## ############# #####################

main [file dirname [file normalize [info script]]]
exit
