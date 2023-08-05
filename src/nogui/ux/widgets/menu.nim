import menu/[base, items]
export menuitem, menuseparator

# --------------
# GUI Menu Popup
# --------------

widget GUIMenu:
  attributes:
    top: GUIMenu
    label: string
    # Current Menu Handle
    selected: GUIMenuItem

  callback cbClose:
    self.close()
    # Close Top Levels
    let top = self.top
    if not isNil(top):
      push(top.cbClose)
    # Remove Selected
    self.selected = nil

  new menu(label: string):
    result.kind = wgMenu
    result.flags = wMouseKeyboard
    result.label = label

  method draw(ctx: ptr CTXRender) =
    let 
      colors = addr getApp().colors
      rect = rect self.rect
    # Fill Menu Container
    ctx.color(colors.panel)
    ctx.fill(rect)
    ctx.color(colors.darker)
    ctx.line(rect, 2)

  proc fit(w, h: int32) =
    let 
      m = addr self.metrics
      r = addr self.rect
    # Ajust Relative
    m.minW = int16 w
    m.minH = int16 h
    m.w = m.minW
    m.h = m.minH
    # Ajust Absolute
    r.w = w
    r.h = h

  method layout =
    let first = self.first
    var y, width: int16
    const border = 2
    # Calculate Max Width
    for widget in forward(first):
      if widget.vtable != self.vtable:
        width = max(widget.metrics.minW, width)
    # Arrange Widgets by Min Size
    for widget in forward(first):
      var w {.cursor.} = widget
      # Warp submenu into a menuitem
      if widget.vtable == self.vtable:
        let 
          w0 = cast[GUIMenu](w)
          w1 = cast[GUIMenuOpaque](w)
          item = menuitem(w0.label, w1)
        # Change Top Level
        w0.top = self
        # Warp into Item
        w.replace(item)
        w.kind = wgMenu
        w = item
      # Bind Menu With Item
      if w of GUIMenuItem:
        let item = cast[GUIMenuItem](w)
        item.ondone = self.cbClose
        item.portal = addr self.selected
      # Arrange Found Widget
      let 
        metrics = addr w.metrics
        h = metrics.minH
      metrics.x = border
      metrics.y = border + y
      metrics.w = width
      metrics.h = h
      # Step Height
      y += h
    # Offset Border
    width += border shl 1
    y += border shl 1
    # Fit Window Size
    self.fit(width, y)

  method handle(kind: GUIHandle) =
    let s = self.selected
    if kind == outFrame and not isNil(s):
      push(s.onportal)
      # Remove Selected
      self.selected = nil

# ------------
# GUI Menu Bar
# ------------

widget GUIMenuBar:
  new menubar():
    result.flags = wMouse

  method draw(ctx: ptr CTXRender) =
    discard

  method layout =
    discard