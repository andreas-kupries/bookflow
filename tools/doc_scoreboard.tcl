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
    #puts Scanning\ $topdir...

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
    #puts \t$f...

    array set t {}
    set TUPLE {}

    foreach line [split [fileutil::cat $f] \n] {
	set line [string trim $line]
	switch -glob -- $line {
	    \#* {
		# ... pragmas
		if {[string match {*@SB *} $line]} {
		    regexp {@SB (.*)$} $line -> TUPLE
		}
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
			    set tuple [tuple line]
			    lappend t($tuple) $method
			}
		    }
		    take -
		    takeall -
		    peek -
		    wpeek {
			set tuple [tuple line]
			lappend t($tuple) $method
		    }
		    unbind -
		    bind {
			set event [word line]
			set tuple [tuple line]
			lappend t($tuple) [list $method $event]
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
    # result = dict (file -> dict (tuple -> list (action...)))
}

proc tuple {svar} {
    upvar 1 $svar string TUPLE TUPLE
    set tuple [word string]
    if {$TUPLE ne {}} {
	set tuple $TUPLE
	set TUPLE {}
    }
    return $tuple
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
	# strip the braces.
	set word [string range $word 1 end-1]
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
    # db = dict (file -> dict (tuple -> list (action...)))

    #array set d $db
    #parray d

    # Invert the structure to make the tuple (patterns) the major index.
    # D = dict (tuple -> dict (action -> list (file...)))

    set D {}
    foreach {fname data} $db {
	foreach {tuple actions} $data {
	    set actions [lsort -unique $actions]
	    set A {}
	    foreach a $actions {
		dict lappend A $a $fname
	    }
	    dict lappend D $tuple $A
	}
    }
    set db $D
    set D {}
    foreach {tuple data} $db {
	# data = list (dict (action -> list(fname)))
	array set X {}
	foreach dict $data {
	    lassign $dict action files
	    lappend X($action) {*}$files
	}
	#parray X
	lappend D $tuple [array get X]
	array unset X
    }

    #puts $D
    #return

    # Write structure in machine- and human-readable form.
    foreach {tuple fa} [dictsort $D] {
	puts "\ntuple [list $tuple] \{"
	# todo description - get via pragma's
	puts "\} \{"
	#puts "==== $fa ===="
	foreach {action files} [dictsort $fa] {
	    set files [lsort -unique $files]
	    puts "    $action \{\n\t[join $files "\n\t"]\n    \}"
	}
	puts "\}"
    }

    #array set T $D
    #parray T
    return
}

proc dictsort {dict} {
    array set a $dict
    set out [list]
    foreach key [lsort [array names a]] {
	lappend out $key $a($key)
    }
    return $out
}

# ## ### ##### ######## ############# #####################

main [file dirname [file normalize [info script]]]
exit
