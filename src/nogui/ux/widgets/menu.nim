import menu/[base, items]
export menuitem, menuseparator

# --------------
# GUI Menu Popup
# --------------

widget GUIMenu:
  attributes:
    top: GUIWidget
    label: string
    # Current Menu Handle
    selected: GUIMenuItem

  callback cbClose:
    self.close()
    # Close Top Levels
    let top = self.top
    if not isNil(top) and top.vtable == self.vtable:
      let m = cast[GUIMenu](top)
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

  method event(state: ptr GUIState) =
    let top = self.top
    if not self.test(wHover) and 
      not isNil(top) and 
      self.vtable != top.vtable:
        # TODO: event propagation
        top.event(state)

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

widget GUIMenuBarItem:
  attributes:
    menu: GUIMenu
    # Current Selected Handle
    portal: ptr GUIMenuBarItem

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

  new menubar0(menu: GUIMenuOpaque):
    result.flags = wMouse
    let 
      m = cast[GUIMenu](menu)
      metrics = addr getApp().font
      fontsize = metrics.size
      # Minimun Size With Padding
      height = metrics.height + fontsize
      width = m.label.width + (fontsize shl 1)
    # Ajust New Size
    result.minimum(width, height)
    # Set Current Menu
    result.menu = m

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      metrics = addr app.font
      colors = addr app.colors
      # Font Size
      fontsize = metrics.size
      rect = addr self.rect
    # Fill Background
    if self.test(wHover) or self.portal[] == self:
      ctx.color colors.item
      ctx.fill rect rect[]
    # Draw Menu Bar Item Text
    ctx.color(colors.text)
    ctx.text(
      rect.x + fontsize,
      rect.y + fontsize,
      self.menu.label)

  method event(state: ptr GUIState) =
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

widget GUIMenuBar:
  attributes:
    # Selected Menu Item
    selected: GUIMenuBarItem

  new menubar():
    result.flags = wMouse

  method layout =
    var x, height: int16
    let portal = addr self.selected
    # Get Max Height and Warp Menus
    for widget in forward(self.first):
      var w {.cursor.} = widget
      # Warp Into Menubar Item
      if w of GUIMenu:
        let
          w0 = cast[GUIMenu](w)
          item = menubar0 GUIMenuOpaque(w0)
        # Warp Into Item
        w0.replace(item)
        w0.top = self
        w0.kind = wgPopup
        w0.cbClose = item.cbMenuClose
        w = item
      # Calculate Max Height
      height = max(height, w.metrics.minH)
    # Arrange Widgets by Horizontal
    let y = self.metrics.y
    for widget in forward(self.first):
      # Bind Menu Bar Items
      if widget of GUIMenuBarItem:
        cast[GUIMenuBarItem](widget).portal = portal
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
    # Fit Menu Bar
    self.fit(x, height)

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
