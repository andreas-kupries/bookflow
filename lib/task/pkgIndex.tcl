if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded task::thread 0.1 [list source [file join $dir task.tcl]]
package ifneeded task         0.1 {package require task::thread ; package provide task 0.1}
