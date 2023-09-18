import menu/[base, items]
export menuitem, menuseparator

# --------------
# GUI Menu Popup
# --------------

widget UXMenu:
  attributes:
    top: GUIWidget
    label: string
    # Current Menu Handle
    selected: UXMenuItem

  callback cbClose:
    self.close()
    # Close Top Levels
    let top = self.top
    if not isNil(top) and top.vtable == self.vtable:
      let m = cast[UXMenu](top)
      push(m.cbClose)
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

  method update =
    const pad = 4
    # Initial Max Width
    var y, width: int16
    width = self.metrics.w - pad
    # Calculate Max Width
    for widget in forward(self.first):
      var w {.cursor.} = widget
      # Warp submenu into a menuitem
      if w.vtable == self.vtable:
        let 
          w0 = cast[UXMenu](w)
          w1 = cast[UXMenuOpaque](w0)
          item = menuitem(w0.label, w1)
        # Change Top Level
        w0.top = self
        # Warp into Item
        w0.replace(item)
        w0.kind = wgMenu
        w = item
      # Bind Menu With Item
      if w of UXMenuItem:
        let item = cast[UXMenuItem](w)
        item.ondone = self.cbClose
        item.portal = addr self.selected
      # Calculate Max Width
      width = max(w.metrics.minW, width)
      y += w.metrics.minH
    # Offset Border
    width += pad
    y += pad
    # Fit Menu Size
    self.fit(width, y)

  method layout =
    const 
      border = 2
      pad = 4
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

  method event(state: ptr GUIState) =
    let top = self.top
    if not self.test(wHover):
      if not isNil(top) and 
        self.vtable != top.vtable:
          # TODO: event propagation
          top.event(state)
      elif isNil(top) and state.kind == evCursorClick:
        # This is Top Level
        self.close()

  method handle(kind: GUIHandle) =
    let s = self.selected
    if kind == outFrame and not isNil(s):
      if valid(s.onportal):
        push(s.onportal)
      # Remove Selected
      self.selected = nil

# -----------------
# GUI Menu Bar Item
# -----------------

widget UXMenuBarItem:
  attributes:
    menu: UXMenu
    # Current Selected Handle
    portal: ptr UXMenuBarItem

  proc onportal() =
    let menu {.cursor.} = self.menu
    # Open Menu or Close Menu
    if self.portal[] == self:
      let rect = addr self.rect
      menu.open()
      # Move Down Menu Item
      menu.move(rect.x, rect.y + rect.h)
    else: menu.close()

  callback cbMenuClose:
    self.portal[] = nil
    # Close Menu
    let m {.cursor.} = self.menu
    m.selected = nil
    m.close()

  new menubar0(menu: UXMenuOpaque):
    result.flags = wMouse
    result.menu = cast[UXMenu](menu)

  method update =
    let
      # TODO: allow customize margin
      font = addr getApp().font
      pad0 = font.size
      pad1 = pad0 shl 1
      # Font Width
      m = addr self.metrics
      w = int16 width(self.menu.label)
      h = font.height
    # Set Minimun Size
    m.minW = w + pad1
    m.minH = h + pad0

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
      font = addr app.font
      # Font Metrics
      ox = self.metrics.minW - (font.size shl 1)
      oy = font.height - font.baseline
    # Fill Background
    if self.test(wHover) or self.portal[] == self:
      ctx.color colors.item
      ctx.fill rect rect[]
    # Draw Text Centered
    ctx.color(colors.text)
    ctx.text(
      rect.x + (rect.w - ox) shr 1,
      rect.y + (rect.h - oy) shr 1, 
      self.menu.label)

  method event(state: ptr GUIState) =
    # Remove Grab Flags
    self.flags.clear(wGrab)
    # Open or Close Menu with Click
    if state.kind == evCursorClick:
      let
        portal = self.portal
        select = portal[]
      # Open or Close Menu
      if isNil(select):
        portal[] = self
      elif select == self:
        portal[] = nil
      # Update Current Menu
      self.onportal()

  method handle(kind: GUIHandle) =
    if kind == inHover:
      let 
        portal = self.portal
        w = portal[]
      if not isNil(w) and w != self:
        portal[] = self
        # React to Change
        w.onportal()
        self.onportal()

# ------------
# GUI Menu Bar
# ------------

widget UXMenuBar:
  attributes:
    # Selected Menu Item
    selected: UXMenuBarItem

  new menubar():
    result.flags = wMouse

  method update =
    var x, height: int16
    let portal = addr self.selected
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
        w0.kind = wgPopup
        w0.cbClose = item.cbMenuClose
        w = item
        # Update New Menu
        item.vtable.update(item)
      # Bind Portal to MenuBarItem
      if w of UXMenuBarItem:
        cast[UXMenuBarItem](w).portal = portal
      # Calculate Max Height
      height = max(height, w.metrics.minH)
      x += w.metrics.minW
    # Fit Menu Bar
    self.fit(x, height)

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
    # Find Inner Widget
    if not isNil(self.selected):
      let w = self.find(state.mx, state.my)
      if w.parent == self:
        w.handle(inHover)
        w.event(state)
      # Close Cursor When Clicked Outside
      elif state.kind == evCursorClick:
        let prev {.cursor.} = self.selected
        self.selected = nil
        prev.onportal()

# ---------------
# GUI Menu Export
# ---------------

# TODO: allow do export on builder
export UXMenu
