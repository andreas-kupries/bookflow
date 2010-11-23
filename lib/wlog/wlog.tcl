## -*- tcl -*-
# ### ### ### ######### ######### #########

# A simple log window where system activity can be shown to the end user.

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
    constructor {} {
	installhull using widget::scrolledwindow \
	    -borderwidth 1 -relief sunken

	text $win.log -height 5 -width 80 -font {Helvetica -18}
	$hull setwidget $win.log

	return
    }

    method puts {text} {
	$self puts* $text\n
	return
    }

    method puts* {text} {
	$win.log configure -state normal
	$win.log insert end $text
	$win.log see end
	$win.log configure -state disabled
	return
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide widget::log 0.1
