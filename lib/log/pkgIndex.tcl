if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded blog 1.0 [list source [file join $dir log.tcl]]

