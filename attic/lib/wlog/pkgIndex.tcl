if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded widget::log 0.1 [list source [file join $dir wlog.tcl]]
