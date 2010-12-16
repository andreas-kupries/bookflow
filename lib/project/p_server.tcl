## -*- tcl -*-
# ### ### ### ######### ######### #########

# Access to a bookflow project database. The actual access is through
# the bookflow::db package. This package simply wraps around it, to
# serialize any access from all the threads of the application, acting
# as an in-application server. This server runs in its own thread.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require bookflow::db

namespace eval ::bookflow::project {}

# ### ### ### ######### ######### #########
## Tracing

debug off    bookflow/project
#debug on     bookflow/project

# ### ### ### ######### ######### #########

::apply {{} {
    task launch [list ::apply {{} {
	package require scoreboard

	# Wait for the appearance of (DATABASE *)
	scoreboard wpeek {DATABASE *} {::apply {{tuple} {
	    lassign $tuple _ dbfile

	    # Pull the project location
	    scoreboard wpeek {AT *} [list ::apply {{dbfile tuple} {
		lassign $tuple _ project

		package require bookflow::db

		set dbfile $project/$dbfile
		if {![file exists  $dbfile]} {
		    [bookflow::db new $dbfile] destroy
		}

		::bookflow::db ::bookflow::project $dbfile

		set id [thread::id]
		scoreboard put [list PROJECT SERVER $id]
		return
	    }} $dbfile]

	    return
	}}}
    }}]
}}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::project::server 0.1
return
