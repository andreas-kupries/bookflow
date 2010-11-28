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

	#install myselchanged using uevent::onidle ${selfns}::SC [mymethod SelectionChanged]

	$self Widgets
	$self Layout
	$self Bindings

	$self S-orient horizontal
	$self STYLE

	$self configurelist $args
	return
    }

    # Add an empty image to the widget. Displayed, but without text or
    # image until such are configured. Returns a token to address the
    # item with.

    method new {} {
	Debug.img/strip {}

	set newitem [$mytree item create]
	$mytree item lastchild 0 $newitem
	$mytree item configure   $newitem -button 0
	$mytree item configure   $newitem -visible 1
	$mytree item style set   $newitem 0 STYLE
	$mytree collapse         $newitem
	$self Resort
	$self DetermineHeight
	$self DetermineWidth

	Debug.img/strip {/}
	return $newitem
    }

    method drop {token} {
	Debug.img/strip {}

	$mytree item delete $token
	# Note: Resorting not needed, the other images are staying in
	# their proper order.

	Debug.img/strip {/}
	return
    }

    method itemconfigure {token args} {
	foreach {option value} $args {
	    $self ItemConfigure $option $token $value
	}
	return
    }

    method {ItemConfigure -message} {token string} {
	Debug.img/strip {}

	$mytree item element configure $token 0 eText -text  $string

	Debug.img/strip {/}
	return
    }

    method {ItemConfigure -label} {token string} {
	Debug.img/strip {}

	$mytree item element configure $token 0 eLabel -text $string

	Debug.img/strip {/}
	return
    }

    method {ItemConfigure -order} {token string} {
	Debug.img/strip {}

	$mytree item element configure $token 0 eSerial -text $string
	$self Resort

	Debug.img/strip {/}
	return
    }

    method {ItemConfigure -image} {token photo} {
	Debug.img/strip {}

	$mytree item element configure $token 0 eImage -image $photo

	Debug.img/strip {/}
	return
    }

    method itemcget {token option} {
	return [$self ItemCget $option $token]
    }

    method {ItemCget -message} {token} {
	Debug.img/strip {}

	if {[catch {
	    set res [$mytree item element cget $token 0 eText -text]
	}]} { set res {} }

	Debug.img/strip {= $res /}
	return $res
    }

    method {ItemCget -label} {token} {
	Debug.img/strip {}

	if {[catch {
	    set res [$mytree item element cget $token 0 eLabel -text]
	}]} { set res {} }

	Debug.img/strip {= $res /}
	return $res
    }

    method {ItemCget -order} {token} {
	Debug.img/strip {}

	if {[catch {
	    set res [$mytree item element cget $token 0 eSerial -text]
	}]} { set res {} }

	Debug.img/strip {= $res /}
	return $res
    }

    method {ItemCget -image} {token} {
	Debug.img/strip {}

	if {[catch {
	    set res [$mytree item element cget $token 0 eImage -image]
	}]} { set res {} }

	Debug.img/strip {= $res /}
	return $res
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
	    -yscrolldelay {500 50}
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

	#$mytree notify bind $mytree <ActiveItem> [mymethod ChangeActiveItem %p %c]
	#$mytree notify bind $mytree <Selection>  [mymethod Selection]

	#bind $mytree <Double-1> [mymethod Action        %x %y]
	#bind $mytree <3>        [mymethod Context %X %Y %x %y]
	#bind $win    <FocusIn>  [mymethod Focus]

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
	# eSerial : INVISIBLE text whose contents determine display order. I.e.
	#           this one is used to sort the items.
	# ------------------------------------------------------------------------

	$mytree element create eImage  image -image {} -width $oursize -height $oursize
	$mytree element create eText   text -text {}        -fill $ourtextfillcolor -justify center
	$mytree element create eLabel  text -text {}        -fill $ourtextfillcolor -justify center
	$mytree element create eFrame  rect -outlinewidth 1 -fill $ourfillcolor -outline $ouroutlinecolor
	$mytree element create eShadow rect -outlinewidth 2 -fill $ourfillcolor -outline gray \
	    -open wn -showfocus 1
	$mytree element create eSerial text -text {}

	$mytree style create   STYLE -orient vertical
	$mytree style elements STYLE {eShadow eLabel eFrame eImage eText eSerial}

	$mytree style layout   STYLE eLabel  -ipady {2 0} -expand we
	$mytree style layout   STYLE eFrame  -union { eImage eText }
	$mytree style layout   STYLE eImage  -ipady $ourgap -ipadx $ourgap -expand swen
	$mytree style layout   STYLE eShadow -padx {1 2} -pady {1 2} -iexpand xy -detach yes

	#$mytree style layout STYLE eLabel -visible 1
	#$mytree style layout STYLE eImage -visible 1
	$mytree style layout STYLE eSerial -visible 0

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

    method Resort {} {
	# Regenerate the display order of items.
	# We sort them by the third text element, the invisible "eSerial".
	$mytree item sort 0 -dict -element eSerial
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

		# Tree is horizontal, no wrapping is done.

		# Each item is as high as myheight (to be determined
		# after first item added).

		# Indirectly derived from 'oursize', the w/h given to
		# the eImage element.

		# FUTURE: Pull this out of the actual image configured
		# for the first item (max of all maybe ?)

		$mytree configure -orient horizontal -wrap {}
		$hull configure -scrollbar horizontal -auto horizontal
		$self DetermineHeight
	    }
	    vertical {
		# Tree is vertical, no wrapping is done.

		# Each item is as wide as mywidth (to be determined
		# after first item added).

		# Indirectly derived from 'oursize', the w/h given to
		# the eImage element.

		# FUTURE: Pull this out of the actual image configured
		# for the first item (max of all maybe ?)

		$mytree configure -orient vertical -wrap {}
		$hull configure -scrollbar vertical -auto vertical
		$self DetermineWidth
	    }
	}
	return
    }

    method DetermineHeight {} {
	if {![info exists options(-orientation)]} return
	if {$options(-orientation) ne "horizontal"} return
	if {$myheight eq {}} {
	    set items [$mytree item children 0]
	    if {![llength $items]} return

	    lassign [$mytree item bbox [lindex $items 0]] _ _ _ myheight
	    incr myheight 40
	}

	$mytree configure -height $myheight -width 0
	return
    }

    method DetermineWidth {} {
	if {![info exists options(-orientation)]} return
	if {$options(-orientation) ne "vertical"} return
	if {$mywidth eq {}} {
	    set items [$mytree item children 0]
	    if {![llength $items]} return

	    lassign [$mytree item bbox [lindex $items 0]] _ _ mywidth _
	    #incr mywidth 40
	}

	#$mytree column configure 0 -width $mywidth
	$mytree configure -width $mywidth -height 0
	return
    }

    # ### ### ### ######### ######### #########
    ## State

    variable myimages {}       ; # List of images shown
    variable myitem  -array {} ; # image -> item
    variable myimage -array {} ; # item -> image
    variable mydata  -array {} ; # item -> list (type, data), type in {photo,text}
    variable mywidth  {} ; # Strip width, derived from first image
    variable myheight {} ; # Strip height, derived from first image
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
