## -*- tcl -*-
# ### ### ### ######### ######### #########

# The main window for each book found in the project.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require Tk
package require snit
package require img::strip ; # Strip of thumbnail images at the top.

# ### ### ### ######### ######### #########
## Tracing

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor ::bookw {
    # ### ### ### ######### ######### #########
    ##

    constructor {book scoreboard} {
	installhull using ttk::frame
	set mybook $book
	set mysb   $scoreboard

	$self Widgets
	$self Layout
	$self Bindings
	return
    }

    destructor {
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
    ##

    variable mybook ; # Name of the book this is connected to
    variable mysb   ; # Command to access the scoreboard.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide bookw 0.1
return
