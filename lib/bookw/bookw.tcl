## -*- tcl -*-
# ### ### ### ######### ######### #########

# The main window for each book found in the project.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require Tk
package require snit
package require iq
package require img::strip ; # Strip of thumbnail images at the top.
package require debug
package require debug::snit
package require blog
package require img::png
package require rbc

# ### ### ### ######### ######### #########
## Tracing

debug prefix bookw {[::debug::snit::call]}
#debug off    bookw
debug on     bookw

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor ::bookw {
    option -log -default {}

    # ### ### ### ######### ######### #########
    ##

    constructor {book scoreboard project args} {
	Debug.bookw {}

	installhull using ttk::frame
	set mytqueue  [iq ${selfns}::QT 4] ; # TODO : Query producer for allowed rate.
	set myproject $project
	set mybook    $book
	set mysb      $scoreboard
	set mypattern [list IMAGE * $book]

	$self Widgets
	$self Layout
	$self Bindings

	# Note: We are peek'ing because at this time images for the
	# named book might have already been added to the scoreboard,
	# which won't be caught by the 'put' event we are registering.

	$mysb peek      $mypattern [mymethod BookImages]
	$mysb bind put  $mypattern [mymethod BookImageNew]
	$mysb bind take $mypattern [mymethod BookImageDel]

	$self configurelist $args

	Debug.bookw {/}
	return
    }

    destructor {
	Debug.bookw {}

	$mysb unbind put  $mypattern [mymethod BookImageNew]
	$mysb unbind take $mypattern [mymethod BookImageDel]

	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########
    ##

    method Widgets {} {
	# Chart of brightness values for the page images.
	rbc::graph $win.chart -height 100

	# Strip of thumbnails for the page images.
	img::strip $win.strip -orientation vertical

	#::widget::pages    .pages
	return
    }

    method Layout {} {
	pack $win.strip    -side left   -fill both -expand 0
	pack $win.chart    -side top    -fill both -expand 0
	#pack $win.strip    -side top    -fill both -expand 0
	#pack .pages   -side top    -fill both -expand 1
	return
    }

    method Bindings {} {
	return
    }

    # ### ### ### ######### ######### #########

    method BookImages {tuples} {
	# tuples = list ((IMAGE path serial book)...)
	Debug.bookw {}

	# For ease of processing we simply run these through
	# BookImageNew...

	foreach t $tuples {
	    $self BookImageNew $t
	}

	Debug.bookw {/}
	return
    }

    method BookImageNew {tuple} {
	# tuple = (IMAGE path serial book)
	Debug.bookw {}

	lassign $tuple _ path serial book
	# TODO : Should assert that book is the expected one.

	incr mycountimages
	$self Log "Book $book ($path /$mycountimages)"

	set token [$win.strip new]
	$win.strip itemconfigure $token \
	    -label   $path \
	    -order   $serial \
	    -message {Waiting for thumbnail...}

	set mytoken($path) $token
	$self WatchThumbnail $path

	Debug.bookw {/}
	return
    }

    method BookImageDel {tuple} {
	# tuple = (IMAGE path serial book)
	Debug.bookw {}

	lassign $tuple _ path serial book
	# TODO : Should assert that book is the expected one.

	incr mycountimages -1
	incr mycountthumb  -1
	$self Log "Book $book ($path /$mycountimages)"

	# doc/interaction_pci.txt (5), release monitor
	$mysb unbind take [list THUMBNAIL $path *] [mymethod InvalidThumbnail]
	# doc/interaction_pci.txt (4) - A waiting wpeek cannot released/canceled.
	#$mysb wpeek [list THUMBNAIL $path *] [mymethod HaveThumbnail]

	set token $mytoken($path)
	unset mytoken($path)
	$win.strip drop $token

	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########

    method WatchThumbnail {path} {
	Debug.bookw {}

	# doc/interaction_pci.txt (5).
	$mysb bind take [list THUMBNAIL $path *] [mymethod InvalidThumbnail]

	# doc/interaction_pci.txt (4). Uses rate-limiting queue
	$mytqueue put [list THUMBNAIL $path *] [mymethod HaveThumbnail]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (5).
    method InvalidThumbnail {tuple} {
	# tuple = (THUMBNAIL image-path thumbnail-path)
	Debug.bookw {}

	lassign $tuple _ path thumb

	# Ignore invalidation of a thumbnail when its image is not
	# used here any longer.

	if {![info exists mytoken($path)]} {
	    Debug.bookw {/}
	    return
	}

	incr mycountthumb -1
	$self Log "Refresh $path $mycountthumb/$mycountimages"

	# Still using the image, therefore request a shiny new valid
	# thumbnail. doc/interaction_pci.txt (4).

	$win.strip itemconfigure $mytoken($path) \
	    -message {Invalidated...}

	$mytqueue put [list THUMBNAIL $path *] [mymethod HaveThumbnail]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (4).
    method HaveThumbnail {tuple} {
	# tuple = (THUMBNAIL image-path thumbnail-path)
	# Paths are relative to the project directory
	Debug.bookw {}

	lassign $tuple _ path thumb

	# Ignore the incoming thumbnail when its image is not used
	# here any longer.

	if {![info exists mytoken($path)]} {
	    Debug.bookw {/}
	    return
	}

	incr mycountthumb
	$self Log "Thumbnail $path $mycountthumb/$mycountimages"

	# Load thumbnail and place it into the strip proper. Careful,
	# retrieve and destroy any previously shown thumbnail first.

	set photo [$win.strip itemcget $mytoken($path) -image]
	if {$photo ne {}} {
	    image delete $photo
	}

	set photo [image create photo -file $myproject/$thumb]
	$win.strip itemconfigure $mytoken($path) \
	    -image   $photo \
	    -message {}

	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########

    method Log {text} {
	if {$options(-log) eq {}} return
	uplevel #0 [list {*}$options(-log) $text]
	return
    }

    # ### ### ### ######### ######### #########
    ##

    variable myproject ; # Path of project directory.
    variable mybook    ; # Name of the book this is connected to
    variable mysb      ; # Command to access the scoreboard.
    variable mypattern ; # Scoreboard pattern for images of this book.

    variable mytoken -array {} ; # Map image PATHs to the associated
				 # TOKEN in the strip of images.

    variable mytqueue     {} ; # Issue queue for thumbnails
    variable mycountimages 0 ; # Number of managed images
    variable mycountthumb  0 ; # Number of managed thumbnails

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide bookw 0.1
return
