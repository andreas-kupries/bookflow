## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Copyright (c) 2010 Andreas Kupries.
## BSD License

## Main package of the book scanning workflow application, aka
## bookflow.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5         ; # Required runtime.
package require Tk
package require blog            ; # End-user visible activity logging,
package require widget::log     ; # and the display for it.
package require widget::toolbar
package require scoreboard
package require bookflow::scan            ; # Task. Scan project directory for images and database
package require bookflow::error           ; # Task. Post error reports to the user.
package require bookflow::create          ; # Task. Create project database when missing and images available.
package require bookflow::verify          ; # Task. Verify project database when existing, and pre-load cached data.
package require bookflow::thumbnail       ; # Task. Generate thumbnails for page images.
package require bookflow::greyscale       ; # Task. Generate greyscale for page images.
package require bookflow::bright          ; # Task. Compute brightness of page images.
package require bookflow::project::server ; # Task. In-application database server.
package require bookw                     ; # Book Display

namespace eval ::bookflow {}

# # ## ### ##### ######## ############# #####################
## API

proc ::bookflow::run {arguments} {
    MakeGUI
    after idle [list after 10 [namespace code [list Start $arguments]]]
    vwait __forever
    return
}

# # ## ### ##### ######## ############# #####################
## Internals

proc ::bookflow::MakeGUI {} {
    wm withdraw .

    Widgets
    Layout
    Bindings

    wm deiconify .
    return
}

proc ::bookflow::Start {arguments} {
    variable project

    Log.bookflow Booting...

    if {![llength $arguments]} {
	set project [pwd]
    } else {
	set project [lindex $arguments 0]
    }

    Log.bookflow {Project in $project}

    bookflow::create         ; # Watch for request to create new project database.
    bookflow::verify         ; # Watch for request to verify existing project database.
    bookflow::error          ; # Watch for error reports
    bookflow::thumbnail      ; # Watch for thumbnail generation requests.
    bookflow::greyscale      ; # Watch for greyscale generation requests.
    bookflow::bright         ; # Watch for brightness calculation requests.
    bookflow::scan $project  ; # Scan project directory

    # TODO :: Launch the other tasklets monitoring the scoreboard for
    # TODO :: their trigger conditions.

    return
}

proc ::bookflow::Widgets {} {
    # Re-style the notebook to use left-side tab-buttons
    ttk::style configure VerticalTabsLeft.TNotebook -tabposition wn

    widget::toolbar .toolbar
    ttk::notebook   .books -style VerticalTabsLeft.TNotebook
    ::widget::log   .log -width 120 -height 2

    .toolbar add button exit -text Exit -command ::exit -separator 1
    return
}

proc ::bookflow::Layout {} {
    pack .toolbar -side top    -fill both -expand 0
    pack .books   -side top    -fill both -expand 1
    pack .log     -side bottom -fill both -expand 0
    return
}

proc ::bookflow::Bindings {} {
    # Redirect log writing into the widget
    ::log on :: 0 .log
    ::log on bookflow

    # Watch and react to scoreboard activity
    # Here: Extend the notebook when new books are announced
    scoreboard bind put  {BOOK *} [namespace code BookNew]
    return
}

# # ## ### ##### ######## ############# #####################

# TODO :: Analyse BookNew/Del for race conditions when a book B is
# TODO :: rapidly added and removed multiple times.

proc ::bookflow::BookNew {tuple} {
    variable bookcounter
    variable project
    lassign $tuple _ name

    set w .books.f$bookcounter
    incr bookcounter

    ::bookw $w $name $project -log Log.bookflow
    .books add $w -sticky nsew -text $name ; # TODO : -image book-icon -compound

    # Watch and react to scoreboard activity
    # Here: Update (shrink) the notebook when this book is removed.
    scoreboard bind take [list BOOK $name] [namespace code [list BookDel $w]]
    return
}

proc ::bookflow::BookDel {w tuple} {
    # Drop the panel from the notebook, and remove the binding which invoked us.
    .books forget $w
    destroy $w
    scoreboard unbind take [list BOOK $name] [namespace code [list BookDel $w]]
    return
}

# # ## ### ##### ######## ############# #####################
## Ready

namespace eval ::bookflow {
    namespace export {[a-z]*}
    namespace ensemble create

    variable bookcounter 0
    variable project     {}
}

package provide bookflow 1.0
return
