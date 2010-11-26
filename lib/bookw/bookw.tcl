## -*- tcl -*-
# ### ### ### ######### ######### #########

# The main window for each book found in the project.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require Tk
package require snit
package require img::strip ; # Strip of thumbnail images at the top.
package require debug
package require debug::snit

# ### ### ### ######### ######### #########
## Tracing

debug prefix bookw {[::debug::snit::call]}
debug on     bookw

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor ::bookw {
    # ### ### ### ######### ######### #########
    ##

    constructor {book scoreboard} {
	Debug.bookw {}

	installhull using ttk::frame
	set mybook    $book
	set mysb      $scoreboard
	set mypattern [list IMAGE * $book]

	$self Widgets
	$self Layout
	$self Bindings

	# Note: We are peek'ing because at this time images for the
	# named book might have already been added to the scoreboard,
	# which won't be caught by the 'put' event we are registering.

	$mysb peek      $mypattern [mymethod BookImages]
	$mysb bind put  $mypattern [mymethod BookImageNew]
	$mysb bind take $mypattern [mymethod BookImageDel]

	Debug.bookw {/}
	return
    }

    destructor {
	Debug.bookw {}

	$mysb unbind put  $mypattern [mymethod BookImageNew]
	$mysb unbind take $mypattern [mymethod BookImageDel]

	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########
    ##

    method Widgets {} {
	#::widget::chart    .chart
	img::strip $win.strip
	#::widget::pages    .pages
	return
    }

    method Layout {} {
	#pack .chart   -side top    -fill both -expand 0
	pack $win.strip    -side top    -fill both -expand 0
	#pack .pages   -side top    -fill both -expand 1
	return
    }

    method Bindings {} {
	return
    }

    # ### ### ### ######### ######### #########

    method BookImages {tuples} {
	# tuples = list ((IMAGE path serial book)...)
	Debug.bookw {}

	# For ease of processing we simply run these through
	# BookImageNew...

	foreach t $tuples {
	    $self BookImageNew $t
	}

	Debug.bookw {/}
	return
    }

    method BookImageNew {tuple} {
	# tuple = (IMAGE path serial book)
	Debug.bookw {}

	lassign $tuple _ path serial _
	# TODO : Should assert that book is the expected one.

	Debug.bookw {/}
	return
    }

    method BookImageDel {tuple} {
	# tuple = (IMAGE path serial book)
	Debug.bookw {}


	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########
    ##

    variable mybook    ; # Name of the book this is connected to
    variable mysb      ; # Command to access the scoreboard.
    variable mypattern ; # Scoreboard pattern for images of this book.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide bookw 0.1
return
