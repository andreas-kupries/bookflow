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
package require bookflow::scan   ; # Task. Scan project directory for images and database
package require bookflow::error  ; # Task. Post error reports to the user.
package require bookflow::create ; # Task. Create project database when missing and images available.

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
    Log.bookflow Booting...

    if {![llength $arguments]} {
	set projectdir [pwd]
    } else {
	set projectdir [lindex $arguments 0]
    }

    Log.bookflow {Project in $projectdir}

    bookflow::create            ; # Watch for request to create new project database.
    bookflow::error             ; # Watch for error reports
    bookflow::scan $projectdir  ; # Scan project directory

    # TODO :: Launch the other tasklets monitoring the scoreboard for
    # TODO :: their trigger conditions.

    return
}

proc ::bookflow::Widgets {} {
    widget::toolbar .toolbar
    #::widget::chart    .chart
    #::widget::imagerow .irow
    ::widget::log      .log
    #::widget::pages    .pages

    .toolbar add button exit -text Exit -command ::exit -separator 1
    return
}

proc ::bookflow::Layout {} {
    pack .toolbar -side top    -fill both -expand 0
    #pack .chart   -side top    -fill both -expand 0
    #pack .irow    -side top    -fill both -expand 0
    #pack .pages   -side top    -fill both -expand 1
    pack .log     -side bottom -fill both -expand 0
    return
}

proc ::bookflow::Bindings {} {
    # Redirect log writing into the widget
    ::log on :: 0 .log
    ::log on bookflow
    return
}

# # ## ### ##### ######## ############# #####################
## Ready

namespace eval ::bookflow {
    namespace export {[a-z]*}
    namespace ensemble create
}

package provide bookflow 1.0
return
