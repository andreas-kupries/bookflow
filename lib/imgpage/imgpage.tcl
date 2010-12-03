## -*- tcl -*-
# ### ### ### ######### ######### #########

# Widget showing a single or double page spread, i.e. one or two
# images. Not specific to bookflow.

# ### ### ### ######### ######### #########
## Requisites

package require Tk 8.5
package require debug
package require debug::snit
package require snit
package require tooltip
package require widget::scrolledwindow

#debug off    img/page
debug on     img/page
debug prefix img/page {[::debug::snit::call] }

# ### ### ### ######### ######### #########
##

snit::widgetadaptor img::page {

    # ### ### ### ######### ######### #########
    ##

    delegate option -borderwidth to hull
    delegate option -relief      to hull

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	Debug.img/page {}

	installhull using ttk::frame

	$self Widgets
	$self Layout
	$self Bindings

	$self configurelist $args
	return
    }

    method {odd image}  {image} { $self Image odd  $image ; return }
    method {even image} {image} { $self Image even $image ; return }

    method {odd text}  {text} { $self Text odd  $text ; return }
    method {even text} {text} { $self Text even $text ; return }

    # ### ### ### ######### ######### #########

    method Image {frame image} {
	Debug.bookw {}

	set mystate($frame,photo) [expr {$image ne {}}]

	set w   [image width  $image]
	set h   [image height $image]
	if {$h > $w} { set max $h } else { set max $w }
	incr max 20

        $win.$frame.plate configure -scrollregion [list 0 0 $max $max]
	$win.$frame.plate itemconfigure PHOTO -image $image
	$win.$frame.plate coords        PHOTO [expr {$w/2 + 10}] [expr {$h/2 + 10}]

	if {$image eq {}} {
	    $win.$frame.plate raise TEXT
	} else {
	    $win.$frame.plate raise PHOTO
	}
	$self Relayout

	Debug.bookw {/}
	return
    }

    method Text {frame text} {
	Debug.bookw {}

	set mystate($frame,text) [expr {$text ne {}}]
	$win.$frame.plate itemconfigure TEXT -text $text
	if {$text eq {}} {
	    $win.$frame.plate raise PHOTO
	} else {
	    $win.$frame.plate raise TEXT
	}
	$self Relayout

	Debug.bookw {/}
	return
    }

    method Relayout {} {
	Debug.bookw {}

	set odd  [expr {$mystate(odd,photo)  || $mystate(odd,text)}]
	set even [expr {$mystate(even,photo) || $mystate(even,text)}]

	if {$odd && $even} {
	    pack $win.odd  -in $win -side left  -fill both -expand 1
	    pack $win.even -in $win -side right -fill both -expand 1
	} elseif {$odd} {
	    pack forget $win.even
	    pack $win.odd -in $win -side top -fill both -expand 1
	} elseif {$even} {
	    pack forget $win.odd
	    pack $win.even -in $win -side top -fill both -expand 1
	} else {
	    pack forget $win.odd
	    pack forget $win.even
	}

	Debug.bookw {/}
	return
    }

    # ### ### ### ######### ######### #########

    method Context {x y} {
	Debug.img/page {}
	event generate $win <<Context>> -data [list $x $y $myimage]
	return
    }

    # ### ### ### ######### ######### #########
    ##

    method Widgets {} {
	foreach frame {
	    odd
	    even
	} {
	    widget::scrolledwindow $win.$frame
	    canvas                 $win.$frame.plate \
		-scrollregion {0 0 1024 1024} \
		-borderwidth 2 -relief sunken

	    $win.$frame setwidget $win.$frame.plate
	    $win.$frame.plate create image 10 10 -tags PHOTO
	    $win.$frame.plate create text  10 10 -tags TEXT -anchor nw -fill red -font {-size -16} -text "Undefined"
	}
	return
    }

    method Layout {} {
	# Layout is dynamic, as images are assigned to the sides, odd
	# packed left, even packed right, both expanding.
	return
    }

    method Bindings {} {
	bind $win.odd.plate  <3> [mymethod Context %X %Y]
	bind $win.even.plate <3> [mymethod Context %X %Y]
	return
    }

    # ### ### ### ######### ######### #########
    ## State

    variable mystate -array {
	odd,photo  0
	odd,text   0
	even,photo 0
	even,text  0
    }

    # ### ### ### ######### ######### #########
    ## Configuration

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide img::page 0.1
