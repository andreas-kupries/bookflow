## -*- tcl -*-
# ### ### ### ######### ######### #########

# A simple log window where system activity can be shown to the end user.
# Not specific to bookflow.

# FUTURE expansion
# Tagging of messages, allowing for customization of appearance (like
# colorization).

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require Tk
package require snit
package require widget::scrolledwindow

# ### ### ### ######### ######### #########
## Tracing

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor ::widget::log {
    delegate option * to mytext

    constructor {args} {
	installhull using widget::scrolledwindow \
	    -borderwidth 1 -relief sunken

	set mytext [text $win.log -height 5 -width 80 -font {Helvetica -18}]
	$hull setwidget $mytext

	$self configurelist $args
	return
    }

    method puts {text} {
	$self puts* $text\n
	return
    }

    method puts* {text} {
	$mytext configure -state normal
	$mytext insert end $text
	$mytext see end
	$mytext configure -state disabled
	return
    }

    # ### ### ### ######### ######### #########
    ##

    variable mytext

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide widget::log 0.1
return
