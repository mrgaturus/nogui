import menu/[base, items, popup]
export
  menuitem,
  menuoption,
  menucheck,
  menuseparator
# Menu Private Access
export popup.menu
privateAccess(UXMenu)

# -----------------
# GUI MenuBar Item
# -----------------

widget UXMenuBarItem:
  attributes:
    {.cursor.}:
      menu: UXMenu
    map: UXMenuMapper
    slot: ptr UXMenuSlot

  callback cbClose:
    self.slot[].reset()

  new menubar0(menu: UXMenuOpaque):
    result.flags = {wMouse, wKeyboard}
    # Hook Menu Callbacks
    let menu = cast[UXMenu](menu)
    menu.cbClose = result.cbClose
    menu.slot.ondone = result.cbClose
    # Define Menu Widget
    result.menu = menu
    result.map = menu.map()

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

  method layout =
    let pivot = addr self.map.pivot
    # Locate Menu Popup Pivot
    pivot.mode = menuVerticalClip
    self.map.locate(self.rect)

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
    if self.test(wHover) or self.slot.item == self:
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
        current = slot.item
      # Open or Close Menu
      if current != self:
        slot[].select(self, addr self.map)
      else: slot[].unselect()

  method handle(reason: GUIHandle) =
    if reason == inHover and not isNil(self.slot.item):
      self.slot[].select(self, addr self.map)

# -----------
# GUI MenuBar
# -----------

widget UXMenuBar:
  attributes:
    slot: UXMenuSlot

  new menubar():
    result.flags = {wMouse, wKeyboard}
    result.kind = wkForward
    # Avoid Delay Menu Mapping
    result.slot.nodelay = true

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
    self.metrics.minfit(x, height)

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
    var flags = self.flags
    # Handle Clicking Outside Menus
    if state.kind == evCursorClick:
      getWindow().send(wsUnGrab)
      flags.incl(wHold)
    elif state.kind == evCursorRelease and wHold in flags:
      self.slot.unselect()
      flags.excl(wHold)
    # Replace Flags
    self.flags = flags
