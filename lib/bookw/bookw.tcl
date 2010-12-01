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
package require struct::set
package require math::statistics
package require bookflow::thumbnail ; # Request encapsulation

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
	install mysqueue  using iq             ${selfns}::QB 4 ; # TODO : Query producer for allowed rate.

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
	#rbc::graph $win.chart -height 100
	rbc::graph $win.chart -height 400

	$win.chart axis configure y          -min 0 -max 256
	$win.chart axis configure y2 -hide 0;# -min 40 -max 160 -title Pulse -stepsize 20

	rbc::vector create ${selfns}::O ; # X-axis, page serial, ordering
	rbc::vector create ${selfns}::B ; # page brightness
	rbc::vector create ${selfns}::D ; # page brightness differences
	rbc::vector create ${selfns}::S ; # page brightness std deviation

	# Chart: Page brightness
	$win.chart element create b \
	    -xdata ${selfns}::O \
	    -ydata ${selfns}::B \
	    -color blue -symbol none -label B

	# Chart: Page brightness delta to previous
	$win.chart element create bd \
	    -xdata ${selfns}::O \
	    -ydata ${selfns}::D \
	    -mapy y2 -color red -symbol none -label D

	# Chart: Page brightness standard deviation.
	$win.chart element create bv \
	    -xdata ${selfns}::O \
	    -ydata ${selfns}::S \
	    -color orange -symbol none -label S

	# Chart: Vertical line for current selection.
	# Starting outside of the axes = invisible.
	$win.chart marker create line -name selection \
	    -fill green -outline green \
	    -coords {-1 -Inf -1 Inf}
	$win.chart marker create text -name tselectionr \
	    -coords {-1 10} -text {} -outline green -anchor w
	$win.chart marker create text -name tselectionl \
	    -coords {-1 250} -text {} -outline green -anchor e

	# Chart: Scatter plot for the points of interest. Enough for
	# all the regular chart plots.
	rbc::vector create ${selfns}::XB
	rbc::vector create ${selfns}::YB
	rbc::vector create ${selfns}::XD
	rbc::vector create ${selfns}::YD
	rbc::vector create ${selfns}::XV
	rbc::vector create ${selfns}::YV

	$win.chart element create boutlier \
	    -xdata ${selfns}::XB \
	    -ydata ${selfns}::YB \
	    -color blue -symbol circle -label {} -linewidth 0

	$win.chart element create doutlier \
	    -xdata ${selfns}::XD \
	    -ydata ${selfns}::YD \
	    -color red -symbol square -label {} -linewidth 0 -mapy y2

	$win.chart element create voutlier \
	    -xdata ${selfns}::XV \
	    -ydata ${selfns}::YV \
	    -color orange -symbol diamond -label {} -linewidth 0

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

	bind $win.strip <<SelectionChanged>> \
	    [mymethod Selection %d]

	bind $win.chart <1> [mymethod ChartSelection %x]
	return
    }

    # ### ### ### ######### ######### #########

    method Selection {selection} {
	Debug.bookw {}

	if {![llength $selection]} return

	set token [lindex $selection 0]
	set path  $mypath($token)
	set at    $myorder($path)

	Debug.bookw { | $token -> $path -> $at}

	# Move the seletion marker and its associated texts (all in
	# the chart) to the new location.

	$win.chart marker configure selection \
	    -coords [list $at -Inf $at Inf]

	$win.chart marker configure tselectionr \
	    -coords [list $at 10] -text $at

	$win.chart marker configure tselectionl \
	    -coords [list $at 250] -text $at

	Debug.bookw {/}
	return
    }

    method ChartSelection {x} {
	Debug.bookw {}

	# Screen to graph coordinates, then selewct the associated image.
	$self Select [expr {int([$win.chart axis invtransform x $x])}]
	return
    }

    method Select {at} {
	# x coordinate to image path, to the token used by the strip.

	Debug.bookw {}
	set path $myopath($at)
	set token $mytoken($path)

	# Set the selection in the strip, this comes back to us via
	# 'Selection' above, which then updates the chart.
	$win.strip selection set $token

	Debug.bookw {/}
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
	    -label   "$path ($serial)" \
	    -order   $serial \
	    -message {Waiting for thumbnail...}

	set mytoken($path)     $token
	set mypath($token)     $path
	set myorder($path)     $serial
	set myopath($serial)   $path

	# Issue requests for the derived data needed by the widget.
	$self GetThumbnail  $path
	$self GetStatistics $path

	if {$mycountimages < 2} {
	    $self Select 0
	    # TODO : GetRegular... (image)
	} else {
	    # Save requests for regular images... These are trickled
	    # into the system when the thumbnails are all done
	    # ... Later, when selections change we hopefully have all
	    # the images to display already ... Might need a
	    # high-priority channel for when selection changes and
	    # images are still trickling through.
	}

	$win.chart axis configure x -min 0 -max $mycountimages

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
	incr mycountstat   -1
	$self Log "Book $book ($path /$mycountimages)"

	# doc/interaction_pci.txt (5), release monitor
	$mysb unbind take [list THUMBNAIL $path *] [mymethod InvalidThumbnail]
	# doc/interaction_pci.txt (4) - A waiting wpeek cannot released/canceled.
	#$mysb wpeek [list THUMBNAIL $path *] [mymethod HaveThumbnail]

	# doc/interaction_pci.txt (5), release monitor
	$mysb unbind take [list STATISTICS $path *] [mymethod InvalidStatistics]
	# doc/interaction_pci.txt (4) - A waiting wpeek cannot released/canceled.
	#$mysb wpeek [list STATISTICS $path *] [mymethod HaveThumbnail]

	set token  $mytoken($path)
	set serial $myorder($path)

	unset mytoken($path)
	unset mypath($token)
	unset myorder($path)
	unset myopath($serial)

	$win.strip drop $token
	$myrbright request

	$win.chart axis configure x -min 0 -max $mycountimages

	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########

    method GetThumbnail {path} {
	Debug.bookw {}

	set request [bookflow::thumbnail::request $path 160]

	# doc/interaction_pci.txt (5).
	$mysb bind take $request [mymethod InvalidThumbnail]

	# doc/interaction_pci.txt (4). Uses rate-limiting queue
	$mytqueue put $request [mymethod HaveThumbnail]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (5).
    method InvalidThumbnail {tuple} {
	# tuple = (THUMBNAIL image-path size thumbnail-path)
	Debug.bookw {}

	lassign $tuple _ path size thumb

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

	$mytqueue put [bookflow::thumbnail::request $path $size] [mymethod HaveThumbnail]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (4).
    method HaveThumbnail {tuple} {
	# tuple = (THUMBNAIL image-path size thumbnail-path)
	# Paths are relative to the project directory
	Debug.bookw {}

	lassign $tuple _ path size thumb

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

    method GetStatistics {path} {
	Debug.bookw {}

	# doc/interaction_pci.txt (5).
	$mysb bind take [list STATISTICS $path *] [mymethod InvalidStatistics]

	# doc/interaction_pci.txt (4). Uses rate-limiting queue
	$mysqueue put [list STATISTICS $path *] [mymethod HaveStatistics]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (5).
    method InvalidStatistics {tuple} {
	# tuple = (STATISTICS image-path statistics)
	Debug.bookw {}

	lassign $tuple _ path statistics

	# Ignore invalidation of statistics when its image is not used
	# here any longer.

	if {![info exists mytoken($path)]} {
	    Debug.bookw {/}
	    return
	}

	incr mycountstat -1
	$self Log "Refresh S $path $mycountstat/$mycountimages"

	# Still using the image, therefore request shiny new valid
	# statistics for it. doc/interaction_pci.txt (4).

	unset mystat($path)
	$myrbright request

	$mysqueue put [list STATISTICS $path *] [mymethod HaveStatistics]

	Debug.bookw {/}
	return
    }

    # doc/interaction_pci.txt (4).
    method HaveStatistics {tuple} {
	# tuple = (STATISTICS image-path statistics)
	# Paths are relative to the project directory
	Debug.bookw {}

	lassign $tuple _ path statistics

	# Ignore the incoming statistics when its image is not
	# used here any longer.

	if {![info exists mytoken($path)]} {
	    Debug.bookw {/}
	    return
	}

	incr mycountstat
	$self Log "Statistics $path $mycountstat/$mycountimages"

	set mystat($path) $statistics
	$myrbright request

	Debug.bookw {/}
	return
    }

    method RefreshBright {} {
	Debug.bookw {}

	# Pull the currently known statistics out of our data
	# structures, put the brightnesses into the proper order, then
	# stuff the result into the chart.

	set o {}
	set b {}
	set s {}
	set d {}
	set l {}

	foreach serial [lsort -dict [array names myopath]] {
	    set path $myopath($serial)
	    if {![info exists mystat($path)]} continue

	    lassign $mystat($path) _ _ mean _ _ stddev _ _
	    # brightness = mean.
	    lappend o $serial
	    lappend b $mean
	    lappend s $stddev
	    lappend d [expr {($l eq {}) ? 0 : ($mean - $l)}]
	    set l $mean
	}

	Debug.bookw { O = ($o)}
	Debug.bookw { B = ($b)}
	Debug.bookw { D = ($d)}
	Debug.bookw { S = ($s)}

	${selfns}::O set $o
	${selfns}::B set $b
	${selfns}::D set $d
	${selfns}::S set $s



	# Outliers, computed from global statistics of the page brightness.

	# Get 2-sigma outliers for page brightness
	lassign [Outlier $o $b] bx by
	# Get 2-sigma outliers for page brightness differences
	lassign [Outlier $o $d] dx dy
	# Get 2-sigma outliers for page brightness stddev
	lassign [DownOutlier $o $s] vx vy

	set ix [lsort -integer [struct::set union $vx [struct::set intersect $bx $dx]]]
	set dict {} ; foreach x $o y $b { lappend dict $x $y }
	set iy {} ; foreach x $ix { lappend iy [dict get $dict $x] }

	${selfns}::XB set $ix
	${selfns}::YB set $iy

	#${selfns}::XD set $dx
	#${selfns}::YD set $dy

	#${selfns}::XV set $vx
	#${selfns}::YV set $vy

	Debug.bookw {/}
	return
    }

    # Find the t-sigma outliers above and below the yseries average.
    proc Outlier {xseries yseries {t 2}} {
	lassign [math::statistics::basic-stats $yseries] \
	    avg min max n stddev var pstddev pvar

	set t [expr {$t * $stddev}]
	set xo {}
	set yo {}
	foreach x $xseries y $yseries {
	    if {abs($y - $avg) < $t} continue
	    lappend xo $x
	    lappend yo $y
	}

	return [list $xo $yo]
    }

    # Find the t-sigma outliers below the yseries average
    proc DownOutlier {xseries yseries {t 2}} {
	lassign [math::statistics::basic-stats $yseries] \
	    avg min max n stddev var pstddev pvar

	set t [expr {$t * $stddev}]
	set xo {}
	set yo {}
	foreach x $xseries y $yseries {
	    if {($avg - $y) < $t} continue
	    lappend xo $x
	    lappend yo $y
	}

	return [list $xo $yo]
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
    variable mypath  -array {}  ; # Map tokens back to their image PATHs.
    variable myorder -array {}  ; # Map image PATHs to the associated
				  # order in the strip of images, and
				  # chart of page brightness,
    variable myopath -array {}  ; # Map serial order to image PATH.
    variable mystat  -array {}  ; # Map image PATHs to the associated
				  # page statistics.

    variable myrbright    {} ; # onidle collator for brightness refresh
    variable mytqueue     {} ; # Issue queue for thumbnails
    variable mysqueue     {} ; # Issue queue for statistics

    variable mycountimages 0 ; # Number of managed images
    variable mycountthumb  0 ; # Number of managed thumbnails
    variable mycountstat   0 ; # Number of managed brightness values

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide bookw 0.1
return
