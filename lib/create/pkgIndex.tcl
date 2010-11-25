if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded bookflow::create 0.1 [list source [file join $dir create.tcl]]
