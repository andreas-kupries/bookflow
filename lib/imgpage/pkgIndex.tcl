if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded img::page 0.1 [list source [file join $dir imgpage.tcl]]
