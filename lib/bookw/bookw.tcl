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
package require uevent::onidle

# ### ### ### ######### ######### #########
## Tracing

debug prefix bookw {[::debug::snit::call]}
debug off    bookw
#debug on     bookw

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor ::bookw {
    option -log -default {}

    # ### ### ### ######### ######### #########
    ##

    constructor {book scoreboard project args} {
	Debug.bookw {}

	installhull using ttk::frame

	install myrbright using uevent::onidle ${selfns}::RBG [mymethod RefreshBright]
	install mytqueue  using iq             ${selfns}::QT 4 ; # TODO : Query producer for allowed rate.
	install mybqueue  using iq             ${selfns}::QB 4 ; # TODO : Query producer for allowed rate.

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

	$win.chart axis configure y          -min 0 -max 256
	$win.chart axis configure y2 -hide 0;# -min 40 -max 160 -title Pulse -stepsize 20

	rbc::vector create ${selfns}::O ; # X-axis, page serial, ordering
	rbc::vector create ${selfns}::B ; # page brightness
	rbc::vector create ${selfns}::D ; # page brightness differences

	$win.chart element create b \
	    -xdata ${selfns}::O \
	    -ydata ${selfns}::B \
	    -color blue
	$win.chart element create bd \
	    -xdata ${selfns}::O \
	    -ydata ${selfns}::D \
	    -mapy y2 -color red

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

	set mytoken($path)     $token
	set myorder(i,$path)   $serial
	set myorder(s,$serial) $path

	# Issue requests for the derived data needed by the widget.
	$self GetThumbnail  $path
	$self GetBrightness $path

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
	incr mycountbright -1
	$self Log "Book $book ($path /$mycountimages)"

	# doc/interaction_pci.txt (5), release monitor
	$mysb unbind take [list THUMBNAIL $path *] [mymethod InvalidThumbnail]
	# doc/interaction_pci.txt (4) - A waiting wpeek cannot released/canceled.
	#$mysb wpeek [list THUMBNAIL $path *] [mymethod HaveThumbnail]

	# doc/interaction_pci.txt (5), release monitor
	$mysb unbind take [list BRIGHTNESS $path *] [mymethod InvalidBrightness]
	# doc/interaction_pci.txt (4) - A waiting wpeek cannot released/canceled.
	#$mysb wpeek [list BRIGHTNESS $path *] [mymethod HaveThumbnail]

	set token  $mytoken($path)
	set serial $myorder(i,$path)

	unset mytoken($path)
	unset myorder(i,$path)
	unset myorder(s,$serial)

	$win.strip drop $token
	$myrbright request

	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########

    method GetThumbnail {path} {
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
	$self Log "Refresh T $path $mycountthumb/$mycountimages"

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

    method GetBrightness {path} {
	Debug.bookw {}

	# doc/interaction_pci.txt (5).
	$mysb bind take [list BRIGHTNESS $path *] [mymethod InvalidBrightness]

	# doc/interaction_pci.txt (4). Uses rate-limiting queue
	$mybqueue put [list BRIGHTNESS $path *] [mymethod HaveBrightness]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (5).
    method InvalidBrightness {tuple} {
	# tuple = (BRIGHTNESS image-path brightness)
	Debug.bookw {}

	lassign $tuple _ path bright

	# Ignore invalidation of a brightness value when its image is
	# not used here any longer.

	if {![info exists mytoken($path)]} {
	    Debug.bookw {/}
	    return
	}

	incr mycountbright -1
	$self Log "Refresh B $path $mycountbright/$mycountimages"

	# Still using the image, therefore request a shiny new valid
	# brightness value for it. doc/interaction_pci.txt (4).

	unset mybright($path)
	$myrbright request

	$mybqueue put [list BRIGHTNESS $path *] [mymethod HaveBrightness]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (4).
    method HaveBrightness {tuple} {
	# tuple = (BRIGHTNESS image-path brightness)
	# Paths are relative to the project directory
	Debug.bookw {}

	lassign $tuple _ path bright

	# Ignore the incoming brightness value when its image is not
	# used here any longer.

	if {![info exists mytoken($path)]} {
	    Debug.bookw {/}
	    return
	}

	incr mycountbright
	$self Log "Brightness $path $mycountbright/$mycountimages"

	set mybright($path) $bright
	$myrbright request

	Debug.bookw {/}
	return
    }

    method RefreshBright {} {
	Debug.bookw {}

	# Pull the currently known brightness values out of our data
	# structures, put them into the proper order, then stuff the
	# result into the chart.

	set o {}
	set b {}
	set l {}
	foreach s [lsort -dict [array names myorder s,*]] {
	    set serial [lindex [split $s ,] end]
	    set path $myorder($s)
	    if {![info exists mybright($path)]} continue
	    set v $mybright($path)
	    lappend o $serial
	    lappend b $v
	    lappend d [expr {($l eq {}) ? 0 : ($v - $l)}]
	    set l $v
	}

	Debug.bookw {O = ($o)}
	Debug.bookw {B = ($b)}
	Debug.bookw {D = ($d)}

	${selfns}::O set $o
	${selfns}::B set $b
	${selfns}::D set $d

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

    variable mytoken -array {}  ; # Map image PATHs to the associated
				  # TOKEN in the strip of images.
    variable myorder -array {}  ; # Map image PATHs to the associated
				  # order in the strip of images, and
				  # chart of page brightness, and the
				  # reverse.
    variable mybright -array {} ; # Map image PATHs to the associated
				  # page brightness.

    variable myrbright    {} ; # onidle collator for brightness refresh
    variable mytqueue     {} ; # Issue queue for thumbnails
    variable mybqueue     {} ; # Issue queue for brightness

    variable mycountimages 0 ; # Number of managed images
    variable mycountthumb  0 ; # Number of managed thumbnails
    variable mycountbright 0 ; # Number of managed brightness values

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide bookw 0.1
return
