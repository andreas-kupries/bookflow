## -*- tcl -*-
# ### ### ### ######### ######### #########

# Widget showing a horizontal/vertical strip of images.
# Not specific to bookflow.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require widget::scrolledwindow
package require treectrl
#package require uevent::onidle
package require snit
#package require struct::set
package require debug::snit
package require debug
package require syscolor

#debug off    img/strip
debug on     img/strip
debug prefix img/strip {[list [::debug::snit::call]] }

snit::widgetadaptor ::img::strip {

    # ### ### ### ######### ######### #########
    ##

    option -orientation \
	-default         horizontal \
	-configuremethod C-orient \
	-type            {snit::enum -values {horizontal vertical}}

    # ### ### ### ######### ######### #########
    ##

    delegate method * to mytree
    delegate option * to mytree
    delegate option -borderwidth to hull
    delegate option -relief      to hull

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	Debug.img/strip {}
	installhull using widget::scrolledwindow -borderwidth 1 -relief sunken

	set mywidth [expr {$oursize + 2*(2+$ourgap)}]

	#install myselchanged using uevent::onidle ${selfns}::SC [mymethod SelectionChanged]

	$self Widgets
	$self Layout
	$self Bindings

	$self S-orient horizontal
	$self STYLE

	$self configurelist $args
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals

    method Widgets {} {
	Debug.img/strip {}

	install mytree using treectrl $win.tree \
	    -highlightthickness 0 \
	    -borderwidth 0 \
	    -showheader 1 \
	    -xscrollincrement 20

	$mytree debug configure \
	    -enable no \
	    -display no \
	    -erasecolor pink \
	    -displaydelay 30

	$mytree configure \
	    -showroot     no \
	    -showbuttons  no \
	    -showlines    no \
	    -selectmode   single \
	    -showheader   no \
	    -scrollmargin 16 \
	    -xscrolldelay {500 50} \
	    -yscrolldelay {500 50} \
	    -itemwidth    $mywidth
	return
    }

    method Layout {} {
	Debug.img/strip {}
	$hull setwidget $mytree
	return
    }

    method Bindings {} {
	Debug.img/strip {}

	# Disable "scan" bindings on windows.
	if {$::tcl_platform(platform) eq "windows"} {
	    bind $mytree <Control-ButtonPress-3> { }
	}

	bindtags $mytree [list $mytree TreeCtrl [winfo toplevel $mytree] all]

	$mytree notify bind $mytree <ActiveItem> [mymethod ChangeActiveItem %p %c]
	$mytree notify bind $mytree <Selection>  [mymethod Selection]

	bind $mytree <Double-1> [mymethod Action        %x %y]
	bind $mytree <3>        [mymethod Context %X %Y %x %y]
	bind $win    <FocusIn>  [mymethod Focus]

	$mytree column create
	return
    }

    method STYLE {} {
	Debug.img/strip {}

	# Style for the items used for the display of images.
	#
	# Elements
	# ------------------------------------------------------------------------
	# eImage  : The image to show.
	# eText   : Transient text, feedback (like the status of image ops, etc.)
	# eLabel  : Textual label for the image.
	# eFrame  : Square rectangle around the image.
	# eShadow : A small drop shadow around eFrame.
	# ------------------------------------------------------------------------

	$mytree element create eImage  image -image {} -width $oursize -height $oursize
	$mytree element create eText   text -text {}        -fill $ourtextfillcolor -justify center
	$mytree element create eLabel  text -text {}        -fill $ourtextfillcolor -justify center
	$mytree element create eFrame  rect -outlinewidth 1 -fill $ourfillcolor -outline $ouroutlinecolor
	$mytree element create eShadow rect -outlinewidth 2 -fill $ourfillcolor -outline gray \
	    -open wn -showfocus 1

	$mytree style create   STYLE -orient vertical
	$mytree style elements STYLE {eShadow eLabel eFrame eImage eText}

	$mytree style layout   STYLE eLabel  -ipady {2 0} -expand we ;#-squeeze x
	$mytree style layout   STYLE eFrame  -union { eImage eText }
	$mytree style layout   STYLE eImage  -ipady $ourgap -ipadx $ourgap -expand swen
	$mytree style layout   STYLE eShadow -padx {1 2} -pady {1 2} -iexpand xy -detach yes

	#$mytree style layout STYLE eLabel -visible 1
	#$mytree style layout STYLE eImage -visible 1

	TreeCtrl::SetSensitive $mytree { {0 STYLE eShadow eLabel eFrame eImage eText} }
	TreeCtrl::SetEditable  $mytree { {0 STYLE} }
	TreeCtrl::SetDragImage $mytree { {0 STYLE} }

	bindtags $mytree \
	    [list \
		 $mytree \
		 TreeCtrlFileList \
		 TreeCtrl \
		 [winfo toplevel $mytree] \
		 all]
	return
    }

    # ### ### ### ######### ######### #########
    ## show helper.

    # ### ### ### ######### ######### #########
    ## NEW helpers

    # ### ### ### ######### ######### #########

    method C-orient {o value} {
	if {$options($o) eq $value} return
	set options($o) $value
	$self S-orient $value
	return
    }

    method S-orient {value} {
	switch -exact -- $value {
	    horizontal {
		# Tree is horizontal, wrapping occurs at right edge
		# of window, each item is as wide as mywidth
		$mytree configure -orient horizontal -wrap window
		$mytree column configure 0 -width 300
	    }
	    vertical {
		# Tree is vertical, no wrapping, column is forced to
		# item width, as the items don't do it for -wrap {}
		$mytree configure -orient vertical -wrap {}
		$mytree column configure 0 -width $mywidth
	    }
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## State

    variable myimages {}       ; # List of images shown
    variable myitem  -array {} ; # image -> item
    variable myimage -array {} ; # item -> image
    variable mydata  -array {} ; # item -> list (type, data), type in {photo,text}
    variable mywidth {}
    variable mydefer 0

    variable  myselection  {}    ; # Set of currently selected images.
    variable  mylastsel    {}
    component myselchanged

    component mytree

    # ### ### ### ######### ######### #########
    ## Configuration

    ## TODO :: Make these configurable (on widget creation only).

    typevariable oursize 160 ; # Maximal size of the images to expect (160x120 / 120x160)
    typevariable ourgap    4 ; # Size of the gap to put between image and text.

    typevariable ourselectcolor  \#ffdc5a
    typevariable ouroutlinecolor \#827878

    typevariable ourfillcolor
    typevariable ourtextfillcolor

    typeconstructor {
	set ourtextfillcolor [list [syscolor::highlightText] {selected focus}]
	set ourfillcolor     [list \
				  [syscolor::highlight] {selected focus} \
				  gray                  {selected !focus}]
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide img::strip 0.1
