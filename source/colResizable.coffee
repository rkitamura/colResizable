(($) ->
  d = $(document) #window object
  h = $("head") #head object
  drag = null #reference to the current grip that is being dragged
  tables = [] #array of the already processed tables (table.id as key)
  count = 0 #internal count to create unique IDs when needed.

  # common strings for minification	(in the minified version there are plenty more)
  ID = "id"
  PX = "px"
  SIGNATURE = "JColResizer"

  # shortcuts
  I = parseInt
  M = Math
  ie = $.browser.msie
  S = undefined
  try # Firefox crashes when executed as local file system
    S = sessionStorage

  # append required CSS rules
  h.append "<style type='text/css'>  .JColResizer{table-layout:fixed;} .JColResizer td, .JColResizer th{overflow:hidden;padding-left:0!important; padding-right:0!important;}  .JCLRgrips{ height:0px; position:relative;} .JCLRgrip{margin-left:-5px; position:absolute; z-index:5; } .JCLRgrip .JColResizer{position:absolute;background-color:red;filter:alpha(opacity=1);opacity:0;width:10px;height:100%;top:0px} .JCLRLastGrip{position:absolute; width:1px; } .JCLRgripDrag{ border-left:1px dotted black;\t}</style>"

  ###
  Function to allow column resizing for table objects. It is the starting point to apply the plugin.
  @param {DOM node} tb - refrence to the DOM table object to be enhanced
  @param {Object} options	- some customization values
  ###
  init = (tb, options) ->
    t = $(tb) #the table object is wrapped
    return destroy(t)  if options.disable #the user is asking to destroy a previously colResized table
    id = t.id = t.attr(ID) or SIGNATURE + count++ #its id is obtained, if null new one is generated
    t.p = options.postbackSafe #shortcut to detect postback safe
    return  if not t.is("table") or tables[id] #if the object is not a table or if it was already processed then it is ignored.
    t.addClass(SIGNATURE).attr(ID, id).before "<div class=\"JCLRgrips\"/>" #the grips container object is added. Signature class forces table rendering in fixed-layout mode to prevent column's min-width
    t.opt = options #t.c and t.g are arrays of columns and grips respectively
    t.g = []
    t.c = []
    t.w = t.width()
    t.gc = t.prev()
    t.gc.css "marginLeft", options.marginLeft  if options.marginLeft #if the table contains margins, it must be specified
    t.gc.css "marginRight", options.marginRight  if options.marginRight #since there is no (direct) way to obtain margin values in its original units (%, em, ...)
    t.cs = I((if ie then tb.cellSpacing or tb.currentStyle.borderSpacing else t.css("border-spacing"))) or 2 #table cellspacing (not even jQuery is fully cross-browser)
    t.b = I((if ie then tb.border or tb.currentStyle.borderLeftWidth else t.css("border-left-width"))) or 1 #outer border width (again cross-browser isues)
    # if(!(tb.style.width || tb.width)) t.width(t.width()); //I am not an IE fan at all, but it is a pitty that only IE has the currentStyle attribute working as expected. For this reason I can not check easily if the table has an explicit width or if it is rendered as "auto"
    tables[id] = t #the table object is stored using its id as key
    createGrips t #grips are created

  ###
  This function allows to remove any enhancements performed by this plugin on a previously processed table.
  @param {jQuery ref} t - table object
  ###
  destroy = (t) ->
    id = t.attr(ID) #its table object is found
    t = tables[id]
    return  if not t or not t.is("table") #if none, then it wasnt processed
    t.removeClass(SIGNATURE).gc.remove() #class and grips are removed
    delete tables[id] #clean up data

  ###
  Function to create all the grips associated with the table given by parameters
  @param {jQuery ref} t - table object
  ###
  createGrips = (t) ->
    th = t.find(">thead>tr>th,>thead>tr>td") #if table headers are specified in its semantically correct tag, are obtained
    th = t.find(">tbody>tr:first>th,>tr:first>th,>tbody>tr:first>td, >tr:first>td")  unless th.length #but headers can also be included in different ways
    t.cg = t.find("col") #a table can also contain a colgroup with col elements
    t.ln = th.length #table length is stored
    memento t, th  if t.p and S and S[t.id] #if 'postbackSafe' is enabled and there is data for the current table, its coloumn layout is restored
    th.each (i) -> #iterate through the table column headers
      c = $(this) #jquery wrap for the current column
      g = $(t.gc.append("<div class=\"JCLRgrip\"></div>")[0].lastChild) #add the visual node to be used as grip
      g.t = t #some values are stored in the grip's node data
      g.i = i
      g.c = c
      c.w = c.width()
      t.g.push g #the current grip and column are added to its table object
      t.c.push c
      c.width(c.w).removeAttr "width" #the width of the column is converted into pixel-based measurements
      if i < t.ln - 1 #bind the mousedown event to start dragging
        g.mousedown(onGripMouseDown).append(t.opt.gripInnerHtml).append "<div class=\"" + SIGNATURE + "\" style=\"cursor:" + t.opt.hoverCursor + "\"></div>"
      else #the last grip is used only to store data
        g.addClass("JCLRLastGrip").removeClass "JCLRgrip"
      g.data SIGNATURE, #grip index and its table name are stored in the HTML
        i: i
        t: t.attr(ID)


    t.cg.removeAttr "width" #remove the width attribute from elements in the colgroup (in any)
    syncGrips t #the grips are positioned according to the current table layout
    # there is a small problem, some cells in the table could contain dimension values interfering with the
    # width value set by this plugin. Those values are removed
    t.find("td, th").not(th).not("table th, table td").each ->
      $(this).removeAttr "width" #the width attribute is removed from all table cells which are not nested in other tables and dont belong to the header


  ###
  Function to allow the persistence of columns dimensions after a browser postback. It is based in
  the HTML5 sessionStorage object, which can be emulated for older browsers using sessionstorage.js
  @param {jQuery ref} t - table object
  @param {jQuery ref} th - reference to the first row elements (only set in deserialization)
  ###
  memento = (t, th) ->
    w = undefined
    m = 0
    i = 0
    aux = []
    if th #in deserialization mode (after a postback)
      t.cg.removeAttr "width"
      if t.opt.flush #if flush is activated, stored data is removed
        S[t.id] = ""
        return
      w = S[t.id].split(";") #column widths is obtained
      while i < t.ln #for each column
        aux.push 100 * w[i] / w[t.ln] + "%" #width is stored in an array since it will be required again a couple of lines ahead
        th.eq(i).css "width", aux[i] #each column width in % is resotred
        i++
      i = 0
      while i < t.ln
        t.cg.eq(i).css "width", aux[i] #this code is required in order to create an inline CSS rule with higher precedence than an existing CSS class in the "col" elements
        i++
    else #in serialization mode (after resizing a column)
      S[t.id] = "" #clean up previous data
      for i of t.c #iterate through columns
        w = t.c[i].width() #width is obtained
        S[t.id] += w + ";" #width is appended to the sessionStorage object using ID as key
        m += w #carriage is updated to obtain the full size used by columns
      S[t.id] += m #the last item of the serialized string is the table's active area (width),

  #to be able to obtain % width value of each columns while deserializing

  ###
  Function that places each grip in the correct position according to the current table layout	 *
  @param {jQuery ref} t - table object
  ###
  syncGrips = (t) ->
    t.gc.width t.w #the grip's container width is updated
    i = 0 #for each column

    while i < t.ln
      c = t.c[i]
      t.g[i].css #height and position of the grip is updated according to the table layout
        left: c.offset().left - t.offset().left + c.outerWidth() + t.cs / 2 + PX
        height: (if t.opt.headerOnly then t.c[0].outerHeight() else t.outerHeight())

      i++

  ###
  This function updates column's width according to the horizontal position increment of the grip being
  dragged. The function can be called while dragging if liveDragging is enabled and also from the onGripDragOver
  event handler to synchronize grip's position with their related columns.
  @param {jQuery ref} t - table object
  @param {nunmber} i - index of the grip being dragged
  @param {bool} isOver - to identify when the function is being called from the onGripDragOver event
  ###
  syncCols = (t, i, isOver) ->
    inc = drag.x - drag.l
    c = t.c[i]
    c2 = t.c[i + 1]
    w = c.w + inc #their new width is obtained
    w2 = c2.w - inc
    c.width w + PX #and set
    c2.width w2 + PX
    t.cg.eq(i).width w + PX
    t.cg.eq(i + 1).width w2 + PX
    if isOver
      c.w = w
      c2.w = w2

  ###
  Event handler used while dragging a grip. It checks if the next grip's position is valid and updates it.
  @param {event} e - mousemove event binded to the window object
  ###
  onGripDrag = (e) ->
    return  unless drag #table object reference
    t = drag.t
    x = e.pageX - drag.ox + drag.l #next position according to horizontal mouse position increment
    mw = t.opt.minWidth #cell's min width
    i = drag.i
    l = t.cs * 1.5 + mw + t.b
    max = (if i is t.ln - 1 then t.w - l else t.g[i + 1].position().left - t.cs - mw) #max position according to the contiguous cells
    min = (if i then t.g[i - 1].position().left + t.cs + mw else l) #min position according to the contiguous cells
    x = M.max(min, M.min(max, x)) #apply boundings
    drag.x = x #apply position increment
    drag.css "left", x + PX
    if t.opt.liveDrag #if liveDrag is enabled
      syncCols t, i #columns and grips are synchronized
      syncGrips t
      cb = t.opt.onDrag #check if there is an onDrag callback
      if cb #if any, it is fired
        e.currentTarget = t[0]
        cb e
    false #prevent text selection

  ###
  Event handler fired when the dragging is over, updating table layout
  ###
  onGripDragOver = (e) ->
    d.unbind("mousemove." + SIGNATURE).unbind "mouseup." + SIGNATURE
    $("head :last-child").remove() #remove the dragging cursor style
    return  unless drag
    drag.removeClass drag.t.opt.draggingClass #remove the grip's dragging css-class
    t = drag.t #get some values
    cb = t.opt.onResize
    if drag.x #only if the column width has been changed
      syncCols t, drag.i, true #the columns and grips are updated
      syncGrips t
      if cb #if there is a callback function, it is fired
        e.currentTarget = t[0]
        cb e
    memento t  if t.p and S #if postbackSafe is enabled and there is sessionStorage support, the new layout is serialized and stored
    drag = null #since the grip's dragging is over

  ###
  Event handler fired when the grip's dragging is about to start. Its main goal is to set up events
  and store some values used while dragging.
  @param {event} e - grip's mousedown event
  ###
  onGripMouseDown = (e) ->
    o = $(this).data(SIGNATURE) #retrieve grip's data
    t = tables[o.t] #shortcuts for the table and grip objects
    g = t.g[o.i]
    g.ox = e.pageX #the initial position is kept
    g.l = g.position().left
    d.bind("mousemove." + SIGNATURE, onGripDrag).bind "mouseup." + SIGNATURE, onGripDragOver #mousemove and mouseup events are bound
    h.append "<style type='text/css'>*{cursor:" + t.opt.dragCursor + "!important}</style>" #change the mouse cursor
    g.addClass t.opt.draggingClass #add the dragging class (to allow some visual feedback)
    drag = g #the current grip is stored as the current dragging object
    if t.c[o.i].l #if the colum is locked (after browser resize), then c.w must be updated
      i = 0
      c = undefined

      while i < t.ln
        c = t.c[i]
        c.l = false
        c.w = c.width()
        i++
    false #prevent text selection

  ###
  Event handler fired when the browser is resized. The main purpose of this function is to update
  table layout according to the browser's size synchronizing related grips
  ###
  onResize = ->
    for t of tables
      t = tables[t]
      i = undefined
      mw = 0
      t.removeClass SIGNATURE #firefox doesnt like layout-fixed in some cases
      unless t.w is t.width() #if the the table's width has changed
        t.w = t.width() #its new value is kept
        i = 0 #the active cells area is obtained
        while i < t.ln
          mw += t.c[i].w
          i++
        #cell rendering is not as trivial as it might seem, and it is slightly different for
        #each browser. In the begining i had a big switch for each browser, but since the code
        #was extremelly ugly now I use a different approach with several reflows. This works
        #pretty well but it's a bit slower. For now, lets keep things simple...

        i = 0
        while i < t.ln
          t.c[i].css("width", M.round(1000 * t.c[i].w / mw) / 10 + "%").l = true
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
      #attributes:
      draggingClass: "JCLRgripDrag" #css-class used when a grip is being dragged (for visual feedback purposes)
      gripInnerHtml: "" #if it is required to use a custom grip it can be done using some custom HTML
      liveDrag: false #enables table-layout updaing while dragging
      minWidth: 15 #minimum width value in pixels allowed for a column
      headerOnly: false #specifies that the size of the the column resizing anchors will be bounded to the size of the first row
      hoverCursor: "e-resize" #cursor to be used on grip hover
      dragCursor: "e-resize" #cursor to be used while dragging
      postbackSafe: false #when it is enabled, table layout can persist after postback. It requires browsers with sessionStorage support (it can be emulated with sessionStorage.js). Some browsers ony
      flush: false #when postbakSafe is enabled, and it is required to prevent layout restoration after postback, 'flush' will remove its associated layout data
      marginLeft: null #in case the table contains any margins, colResizable needs to know the values used, e.g. "10%", "15em", "5px" ...
      marginRight: null #in case the table contains any margins, colResizable needs to know the values used, e.g. "10%", "15em", "5px" ...
      disable: false #disables all the enhancements performed in a previously colResized table
      #events:
      onDrag: null #callback function to be fired during the column resizing process if liveDrag is enabled
      onResize: null #callback function fired when the dragging process is over

    options = $.extend(defaults, options)
    @each ->
      init this, options

) jQuery
