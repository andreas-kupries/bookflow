if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded bookflow::error 0.1 [list source [file join $dir error.tcl]]
