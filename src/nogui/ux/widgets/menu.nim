import menu/[base, items]
# Export Menu Item Variants
export menuitem, menuoption, menucheck, menuseparator

# --------------
# GUI Menu Popup
# --------------

widget UXMenu:
  attributes:
    top: GUIWidget
    label: string
    # Menu Item Slot
    slot: UXMenuSlot

  callback cbClose:
    self.send(wsClose)
    # Close Top Levels
    let top = self.top
    if not isNil(top) and top.vtable == self.vtable:
      let m = cast[UXMenu](top)
      send(m.cbClose)
    # Remove Selected
    self.slot.unselect()

  new menu(label: string):
    result.kind = wkPopup
    result.flags = {wMouse, wKeyboard}
    result.label = label
    # Define Slot Done Callback
    result.slot.ondone = result.cbClose

  method update =
    let pad = getApp().space.line shl 1
    # Initial Max Width
    var y, width: int16
    width = self.metrics.w - pad
    # Calculate Max Width
    for widget in forward(self.first):
      var w {.cursor.} = widget
      # Warp menu into a menuitem
      if w.vtable == self.vtable:
        let 
          w0 = cast[UXMenu](w)
          w1 = cast[UXMenuOpaque](w0)
          item = menuitem(w0.label, w1)
        # Warp into Item
        w0.top = self
        w0.replace(item)
        w = item
      # Bind Menu Slot With Item
      if w of UXMenuItem:
        let item = cast[UXMenuItem](w)
        item.slot = addr self.slot
      # Calculate Max Width
      width = max(w.metrics.minW, width)
      y += w.metrics.minH
    # Offset Border
    width += pad
    y += pad
    # Fit Menu Dimensions
    self.metrics.fit(width, y)

  method layout =
    let
      border = getApp().space.line
      pad = border shl 1
    var y: int16
    # Width for each widget
    let width = self.metrics.minW - pad
    # Arrange Each Widget
    for w in forward(self.first):
      let 
        metrics = addr w.metrics
        h = metrics.minH
      metrics.x = border
      metrics.y = border + y
      metrics.w = width
      metrics.h = h
      # Step Height
      y += h

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      colors = addr app.colors
      border = float32(app.space.line)
      # Menu Fill Region
      rect = rect(self.rect)
    # Fill Menu Container
    ctx.color(colors.panel)
    ctx.fill(rect)
    ctx.color(colors.darker)
    ctx.line(rect, border)

  method event(state: ptr GUIState) =
    if self.test(wGrab): return
    # Propagate Event to Outside
    let top {.cursor.} = self.top
    if not self.test(wHover) and not isNil(top):
      top.send(wsForward)
    elif isNil(top) and state.kind == evCursorRelease:
      self.send(wsClose)

  method handle(reason: GUIHandle) =
    if reason == outFrame:
      self.slot.unselect()

# -----------------
# GUI MenuBar Item
# -----------------

widget UXMenuBarItem:
  attributes:
    menu: UXMenu
    slot: ptr UXMenuSlot

  callback cbPopup:
    let 
      popup = self.menu
      rect = addr self.rect
    if self.slot[].current == self:
      popup.send(wsOpen)
      # Move Down Menu Bar Item
      let m = addr popup.metrics
      m.x = int16(rect.x)
      m.y = int16(rect.y + rect.h)
    # Close Menu if Leaved
    else: popup.send(wsClose)

  callback cbClose:
    self.slot[].unselect()

  new menubar0(menu: UXMenuOpaque):
    result.flags = {wMouse, wKeyboard}
    # Hook Menu Callbacks
    let menu = cast[UXMenu](menu)
    menu.cbClose = result.cbClose
    menu.slot.ondone = result.cbClose
    # Define Menu
    result.menu = menu

  method update =
    let
      app = getApp()
      # Application Padding
      pad = app.space.pad
      pad0 = pad + (pad shr 1)
      pad1 = pad0 shl 1
      # Font Width
      m = addr self.metrics
      w = int16 width(self.menu.label)
      h = app.font.height
    # Set Minimun Size
    m.minW = w + pad1
    m.minH = h + pad0

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
      font = addr app.font
      # Application Padding
      pad = app.space.pad
      pad0 = pad + (pad shr 1)
      # Font Metrics
      ox = self.metrics.minW - (pad0 shl 1)
      oy = font.baseline
    # Fill Menubar Item Highlight
    if self.test(wHover) or self.slot[].current == self:
      ctx.color colors.item
      ctx.fill rect rect[]
    # Draw Text Centered
    ctx.color(colors.text)
    ctx.text(
      rect.x + (rect.w - ox) shr 1,
      rect.y + (rect.h - oy) shr 1, 
      self.menu.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      getWindow().send(wsUnGrab)
    # Open or Close Menu with Click
    if state.kind == evCursorClick:
      let
        slot = self.slot
        current = slot[].current
      # Open or Close Menu
      if current != self:
        slot[].select(self, self.cbPopup)
      else: slot[].unselect()

  method handle(reason: GUIHandle) =
    if reason == inHover and not isNil(self.slot[].current):
      self.slot[].select(self, self.cbPopup)

# -----------
# GUI MenuBar
# -----------

widget UXMenuBar:
  attributes:
    slot: UXMenuSlot

  new menubar():
    result.flags = {wMouse, wKeyboard}
    result.kind = wkForward

  method update =
    var x, height: int16
    let slot = addr self.slot
    # Get Max Height and Warp Menus
    for widget in forward(self.first):
      var w {.cursor.} = widget
      # Warp Into Menubar Item
      if w of UXMenu:
        let
          w0 = cast[UXMenu](w)
          item = menubar0 UXMenuOpaque(w0)
        # Warp Into Item
        w0.replace(item)
        w0.top = self
        w = item
        # Update Created Menu
        item.vtable.update(item)
      # Bind Portal to MenuBarItem
      if w of UXMenuBarItem:
        cast[UXMenuBarItem](w).slot = slot
      # Calculate Max Height
      height = max(height, w.metrics.minH)
      x += w.metrics.minW
    # Fit Menu Bar Dimensions
    self.metrics.fit(x, height)

  method layout =
    var x: int16
    let
      y = self.metrics.y
      height = self.metrics.minH
    for widget in forward(self.first):
      # Arrange Current Widget
      let
        metrics = addr widget.metrics
        w = metrics.minW
      metrics.x = x
      metrics.y = y
      metrics.w = w
      metrics.h = height
      # Step Position
      x += w

  method event(state: ptr GUIState) =
    if self.test(wHover): return
    if state.kind == evCursorClick:
      getWindow().send(wsUnGrab)
    elif state.kind == evCursorRelease:
      self.slot.unselect()
