## -*- tcl -*-
# ### ### ### ######### ######### #########

# Determine and save system colors for use by (mega)widgets to
# visually match an application's appearance to the environment.
# Not specific to bookflow.

# ### ### ### ######### ######### #########
## Requisites

package require Tk

namespace eval ::syscolor {}

# ### ### ### ######### ######### #########
## API

proc ::syscolor::buttonFace    {} { variable buttonFace    ; return $buttonFace    }
proc ::syscolor::highlight     {} { variable highlight     ; return $highlight     }
proc ::syscolor::highlightText {} { variable highlightText ; return $highlightText }

# ### ######### ###########################
## State

namespace eval ::syscolor {
    variable buttonFace
    variable highlight
    variable highlightText
}

# ### ######### ###########################
## Initialization

::apply {{} {
    set w [listbox .__syscolor__]
    variable buttonFace    [$w cget -highlightbackground]
    variable highlight     [$w cget -selectbackground]
    variable highlightText [$w cget -selectforeground]
    destroy $w
    return
} ::syscolor}

# ### ######### ###########################
## Ready

package provide syscolor 0.1
return
