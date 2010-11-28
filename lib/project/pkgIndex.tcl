if {![package vsatisfies [package require Tcl] 8.5]} return
package ifneeded bookflow::project         0.1 [list source [file join $dir p_client.tcl]]
package ifneeded bookflow::project::server 0.1 [list source [file join $dir p_server.tcl]]
