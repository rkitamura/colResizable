(($) ->

  d = $(document) # window object
  h = $("head")   # head object
  drag = null     # reference to the current grip that is being dragged
  tables = []     # array of the already processed tables (table.id as key)
  count = 0       # internal count to create unique IDs when needed.

  # common strings for minification
  # (in the minified version there are plenty more)
  ID = "id"
  PX = "px"
  SIGNATURE = "JColResizer"

  # shortcuts
  ie = $.browser.msie
  S = undefined
  try # Firefox crashes when executed as local file system
    S = sessionStorage

  # append required CSS rules
  h.append """
    <style type='text/css'>
      .JColResizer {table-layout:fixed;}
      .JColResizer td, .JColResizer th {
        overflow:hidden;
        padding-left:0!important;
        padding-right:0!important;
      }
      .JCLRgrips {height:0px; position:relative;}
      .JCLRgrip {margin-left:-5px; position:absolute; z-index:5;}
      .JCLRgrip .JColResizer {
        position:absolute;
        background-color:red;
        filter:alpha(opacity=1);
        opacity:0;
        width:10px;
        height:100%;
        top:0px
      }
      .JCLRLastGrip {position:absolute; width:1px;}
      .JCLRgripDrag {border-left:1px dotted black;}
    </style>
  """

  ###
  Function to allow column resizing for table objects.
  It is the starting point to apply the plugin.
  @param {DOM node} tb - refrence to the DOM table object to be enhanced
  @param {Object} options	- some customization values
  ###
  init = (tb, options) ->
    # the table object is wrapped
    t = $(tb)
    # the user is asking to destroy a previously colResized table
    return destroy(t)  if options.disable
    # its id is obtained, if null new one is generated
    id = t.id = t.attr(ID) or SIGNATURE + count++
    # shortcut to detect postback safe
    t.p = options.postbackSafe
    # if the object is not a table or
    # if it was already processed then it is ignored.
    return if not t.is("table") or tables[id]
    # the grips container object is added.
    # Signature class forces table rendering in fixed-layout mode
    #  to prevent column's min-width
    t.addClass(SIGNATURE).attr(ID, id).before "<div class=\"JCLRgrips\"/>"
    t.opt = options
    # t.c and t.g are arrays of columns and grips respectively
    t.g = []
    t.c = []
    t.w = t.width()
    t.gc = t.prev()
    # if the table contains margins, it must be specified
    # since there is no (direct) way to obtain margin values in
    #  its original units (%, em, ...)
    t.gc.css "marginLeft", options.marginLeft if options.marginLeft
    t.gc.css "marginRight", options.marginRight if options.marginRight
    # table cellspacing (not even jQuery is fully cross-browser)
    if ie
      cellspacing = tb.cellSpacing or tb.currentStyle.borderSpacing
    else
      cellspacing = t.css 'border-spacing'
    t.cs = parseInt(cellspacing, 10) or 2
    # outer border width (again cross-browser isues)
    if ie
      borderWidth = tb.border or tb.currentStyle.borderLeftWidth
    else
      borderWidth = t.css 'border-left-width'
    t.b = parseInt(borderWidth, 10) or 1
    # I am not an IE fan at all, but it is a pitty that only IE has
    #   the currentStyle attribute working as expected. For this reason
    #   I cannot check easily if the table has an explicit width
    #   or if it is rendered as "auto"
    # if(!(tb.style.width || tb.width)) t.width(t.width());
    # the table object is stored using its id as key
    tables[id] = t
    # grips are created
    createGrips t

  ###
  This function allows to remove any enhancements performed
  by this plugin on a previously processed table.
  @param {jQuery ref} t - table object
  ###
  destroy = (t) ->
    # its table object is found
    id = t.attr(ID)
    t = tables[id]
    # if none, then it wasnt processed
    return if not t or not t.is("table")
    # class and grips are removed
    t.removeClass(SIGNATURE).gc.remove()
    # clean up data
    delete tables[id]

  ###
  Function to create all the grips associated with the table given by parameters
  @param {jQuery ref} t - table object
  ###
  createGrips = (t) ->
    # if table headers are specified in its semantically
    #   correct tag, are obtained
    th = t.find(">thead>tr>th,>thead>tr>td")
    # but headers can also be included in different ways
    unless th.length
      selectors = [
        '>tbody>tr:first>th'
        '>tr:first>th'
        '>tbody>tr:first>td'
        '>tr:first>td'
      ]
      th = t.find (selectors.join ',')
    # a table can also contain a colgroup with col elements
    t.cg = t.find 'col'
    # table length is stored
    t.ln = th.length
    # if 'postbackSafe' is enabled and there is data for
    #   the current table, its coloumn layout is restored
    memento t, th if t.p and S and S[t.id]
    # iterate through the table column headers
    th.each (i) ->
      # jquery wrap for the current column
      c = $(this)
      # add the visual node to be used as grip
      g = $(t.gc.append("<div class=\"JCLRgrip\"></div>")[0].lastChild)
      # some values are stored in the grip's node data
      g.t = t
      g.i = i
      g.c = c
      c.w = c.width()
      # the current grip and column are added to its table object
      t.g.push g
      t.c.push c
      # the width of the column is converted into pixel-based measurements
      c.width(c.w).removeAttr "width"
      # bind the mousedown event to start dragging
      if i < t.ln - 1
        hoverStyle = """
          <div class='#{SIGNATURE}' style='cursor:#{t.opt.hoverCursor}'></div>
        """
        g.mousedown(onGripMouseDown)
         .append(t.opt.gripInnerHtml)
         .append hoverStyle
      else
        # the last grip is used only to store data
        g.addClass("JCLRLastGrip").removeClass "JCLRgrip"
      # grip index and its table name are stored in the HTML
      g.data SIGNATURE,
        i: i
        t: t.attr(ID)

    # remove the width attribute from elements in the colgroup (in any)
    t.cg.removeAttr "width"
    # the grips are positioned according to the current table layout
    syncGrips t
    # there is a small problem, some cells in the table
    #   could contain dimension values interfering with the
    # width value set by this plugin. Those values are removed
    t.find("td, th").not(th).not("table th, table td").each ->
      # the width attribute is removed from all table cells
      #  which are not nested in other tables and dont belong to the header
      $(this).removeAttr "width"


  ###
  Function to allow the persistence of columns dimensions
  after a browser postback. It is based in the HTML5 sessionStorage
  object, which can be emulated for older browsers using sessionstorage.js
  @param {jQuery ref} t - table object
  @param {jQuery ref} th - reference to the first row elements
                         (only set in deserialization)
  ###
  memento = (t, th) ->
    w = undefined
    m = 0
    i = 0
    aux = []
    # in deserialization mode (after a postback)
    if th
      t.cg.removeAttr "width"
      # if flush is activated, stored data is removed
      if t.opt.flush
        S[t.id] = ""
        return
      # column widths is obtained
      w = S[t.id].split(";")
      # for each column
      while i < t.ln
        # width is stored in an array since it will be required
        #  again a couple of lines ahead
        aux.push 100 * w[i] / w[t.ln] + "%"
        # each column width in % is resotred
        th.eq(i).css "width", aux[i]
        i++
      i = 0
      while i < t.ln
        # this code is required in order to create an inline
        #   CSS rule with higher precedence than an existing CSS
        #   class in the "col" elements
        t.cg.eq(i).css "width", aux[i]
        i++
    else
      ## in serialization mode (after resizing a column)
      # clean up previous data
      S[t.id] = ""
      # iterate through columns
      for i of t.c
        # width is obtained
        w = t.c[i].width()
        # width is appended to the sessionStorage object using ID as key
        S[t.id] += w + ";"
        # carriage is updated to obtain the full size used by columns
        m += w
      # the last item of the serialized string
      #   is the table's active area (width),
      #   to be able to obtain % width value of each columns while deserializing
      S[t.id] += m

  ###
  Function that places each grip in the correct position
     according to the current table layout
  @param {jQuery ref} t - table object
  ###
  syncGrips = (t) ->
    # the grip's container width is updated
    t.gc.width t.w
    i = 0
    # for each column
    while i < t.ln
      c = t.c[i]
      # height and position of the grip is updated according to the table layout
      if t.opt.headerOnly
        height = t.c[0].outerHeight()
      else
        height = t.outerHeight()
      t.g[i].css
        left: c.offset().left - t.offset().left + c.outerWidth() + t.cs / 2 + PX
        height: height
      i++

  ###
  This function updates column's width according to the horizontal
  position increment of the grip being dragged. The function can be
  called while dragging if liveDragging is enabled and also from
  the onGripDragOver event handler to synchronize grip's position
  with their related columns.
  @param {jQuery ref} t - table object
  @param {nunmber} i - index of the grip being dragged
  @param {bool} isOver - to identify when the function is
                         being called from the onGripDragOver event
  ###
  syncCols = (t, i, isOver) ->
    inc = drag.x - drag.l
    c = t.c[i]
    c2 = t.c[i + 1]
    # their new width is obtained and set
    w = c.w + inc
    w2 = c2.w - inc
    c.width w + PX
    c2.width w2 + PX
    t.cg.eq(i).width w + PX
    t.cg.eq(i + 1).width w2 + PX
    if isOver
      c.w = w
      c2.w = w2

  ###
  Event handler used while dragging a grip.
  It checks if the next grip's position is valid and updates it.
  @param {event} e - mousemove event binded to the window object
  ###
  onGripDrag = (e) ->
    return unless drag
    # table object reference
    t = drag.t
    # next position according to horizontal mouse position increment
    x = e.pageX - drag.ox + drag.l
    # cell's min width
    mw = t.opt.minWidth
    i = drag.i
    l = t.cs * 1.5 + mw + t.b
    # max position according to the contiguous cells
    if i is t.ln - 1
      max = t.w - l
    else
      max = t.g[i + 1].position().left - t.cs - mw
    # min position according to the contiguous cells
    if i
      min = t.g[i - 1].position().left + t.cs + mw
    else
      min = l
    # apply boundings
    x = Math.max(min, Math.min(max, x))
    # apply position increment
    drag.x = x
    drag.css "left", x + PX
    # if liveDrag is enabled
    if t.opt.liveDrag
      # columns and grips are synchronized
      syncCols t, i
      syncGrips t
      # check if there is an onDrag callback
      cb = t.opt.onDrag
      # if any, it is fired
      if cb
        e.currentTarget = t[0]
        cb e
    # prevent text selection
    false

  ###
  Event handler fired when the dragging is over, updating table layout
  ###
  onGripDragOver = (e) ->
    d.unbind("mousemove." + SIGNATURE).unbind "mouseup." + SIGNATURE
    # remove the dragging cursor style
    $("head :last-child").remove()
    return  unless drag
    # remove the grip's dragging css-class
    drag.removeClass drag.t.opt.draggingClass
    # get some values
    t = drag.t
    cb = t.opt.onResize
    # only if the column width has been changed
    if drag.x
      # the columns and grips are updated
      syncCols t, drag.i, true
      syncGrips t
      # if there is a callback function, it is fired
      if cb
        e.currentTarget = t[0]
        cb e
    # if postbackSafe is enabled and there is sessionStorage support,
    #   the new layout is serialized and stored
    #   since the grip's dragging is over
    memento t  if t.p and S
    drag = null

  ###
  Event handler fired when the grip's dragging is about to start.
  Its main goal is to set up events and store some values used while dragging.
  @param {event} e - grip's mousedown event
  ###
  onGripMouseDown = (e) ->
    # retrieve grip's data
    o = $(this).data(SIGNATURE)
    # shortcuts for the table and grip objects
    t = tables[o.t]
    g = t.g[o.i]
    # the initial position is kept
    g.ox = e.pageX
    g.l = g.position().left
    # mousemove and mouseup events are bound
    d.bind "mousemove." + SIGNATURE, onGripDrag
    d.bind "mouseup." + SIGNATURE, onGripDragOver
    # change the mouse cursor
    h.append """
    <style type='text/css'>
      *{cursor:#{t.opt.dragCursor}!important}
    </style>
    """
    # add the dragging class (to allow some visual feedback)
    g.addClass t.opt.draggingClass
    # the current grip is stored as the current dragging object
    drag = g
    # if the colum is locked (after browser resize), then c.w must be updated
    if t.c[o.i].l
      i = 0
      c = undefined

      while i < t.ln
        c = t.c[i]
        c.l = false
        c.w = c.width()
        i++
    # prevent text selection
    false

  ###
  Event handler fired when the browser is resized.
  The main purpose of this function is to update table layout
  according to the browser's size synchronizing related grips
  ###
  onResize = ->
    for t of tables
      t = tables[t]
      i = undefined
      mw = 0
      # firefox doesnt like layout-fixed in some cases
      t.removeClass SIGNATURE
      # if the the table's width has changed
      unless t.w is t.width()
        # its new value is kept
        t.w = t.width()
        i = 0
        # the active cells area is obtained
        while i < t.ln
          mw += t.c[i].w
          i++
        # cell rendering is not as trivial as it might seem, and it
        #   is slightly different for each browser. In the beginning
        #   I had a big switch for each browser, but since the code
        #   was extremely ugly now I use a different approach with
        #   several reflows. This works pretty well but it's a bit slower.
        #   For now, lets keep things simple...
        i = 0
        while i < t.ln
          width = Math.round(1000 * t.c[i].w / mw) / 10 + "%"
          t.c[i].css("width", width).l = true
          i++

      #c.l locks the column, telling us that its c.w is outdated
      syncGrips t.addClass(SIGNATURE)

  #bind resize event, to update grips position
  $(window).bind "resize." + SIGNATURE, onResize

  ###
  The plugin is added to the jQuery library
  @param {Object} options -  an object containg some basic customization values
  ###
  $.fn.extend colResizable: (options) ->
    defaults =
      ## ATTRIBUTES
      # css-class used when a grip is being dragged
      #   (for visual feedback purposes)
      draggingClass: "JCLRgripDrag"
      # if it is required to use a custom grip
      #   it can be done using some custom HTML
      gripInnerHtml: ""
      # enables table-layout updaing while dragging
      liveDrag: false
      # minimum width value in pixels allowed for a column
      minWidth: 15
      # specifies that the size of the the column resizing anchors
      #   will be bounded to the size of the first row
      headerOnly: false
      # cursor to be used on grip hover
      hoverCursor: "e-resize"
      # cursor to be used while dragging
      dragCursor: "e-resize"
      # when it is enabled, table layout can persist after postback.
      #   It requires browsers with sessionStorage support
      #   (it can be emulated with sessionStorage.js).
      postbackSafe: false
      # when postbakSafe is enabled, and it is required to prevent
      #   layout restoration after postback, 'flush' will remove
      #   its associated layout data
      flush: false
      # in case the table contains any margins, colResizable needs
      #   to know the values used, e.g. "10%", "15em", "5px" ...
      marginLeft: null
      # in case the table contains any margins, colResizable needs
      #   to know the values used, e.g. "10%", "15em", "5px" ...
      marginRight: null
      # disables all the enhancements performed in a previously colResized table
      disable: false
      ## EVENTS
      # callback function to be fired during the column
      #  resizing process if liveDrag is enabled
      onDrag: null
      # callback function fired when the dragging process is over
      onResize: null

    options = $.extend(defaults, options)
    @each ->
      init this, options

) jQuery
