if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded bookflow 1.0 [list source [file join $dir bookflow.tcl]]
