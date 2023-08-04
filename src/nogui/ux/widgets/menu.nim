import ../prelude

# ------------------
# GUI Menu Separator
# ------------------

widget GUIMenuSeparator:
  new menuseparator():
    let
      metrics = addr getApp().font
      fontsize = metrics.size
      # Minimun Separator Size
      height = (metrics.height + fontsize) shr 1
    result.minimum(height, height)

  method draw(ctx: ptr CTXRender) =
    ctx.color getApp().colors.item and 0x7FFFFFFF
    var rect = rect(self.rect)
    # Locate Separator Line
    rect.y = (rect.y + rect.yh) * 0.5 - 1
    rect.yh = rect.y + 2
    # Create Simple Line
    ctx.fill rect

widget GUIMenuSeparatorLabel:
  attributes:
    label: string

  new menuseparator(label: string):
    let
      metrics = addr getApp().font
      fontsize = metrics.size
      # Minimun Separator Size
      height = metrics.height + fontsize
      width = label.width + height
    result.minimum(width, height)
    # Set Separator Label
    result.label = label

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      metrics = addr app.font
      colors = addr app.colors
      # Font Size
      fontsize = metrics.size
      rect = addr self.rect
      m = addr self.metrics
      offset = m.minW - m.minH
    # Create Rect
    ctx.color(colors.item and 0x7FFFFFFF)
    ctx.fill rect rect[]
    # Draw Text Centered
    ctx.color(colors.text)
    ctx.text(
      rect.x + (rect.w - offset) shr 1,
      rect.y + fontsize shr 1 - metrics.desc, 
      self.label)

# --------------
# Menu Item Base
# --------------

widget GUIMenuItem:
  attributes:
    label: string
    ondone: GUICallback

  proc init0(label: string) =
    let 
      metrics = addr getApp().font
      fontsize = metrics.size
      # Minimun Size for an Icon
      height = metrics.height + fontsize
      width = label.width + height shl 2
    self.minimum(width, height)
    # Default Flags
    self.flags = wMouseKeyboard
    self.label = label

  proc draw0(ctx: ptr CTXRender) =
    let
      app = getApp()
      metrics = addr app.font
      colors = addr app.colors
      # Font Size
      fontsize = metrics.size
      rect = addr self.rect
    # Fill Background
    if self.test(wHover):
      ctx.color colors.item 
      ctx.fill rect rect[]
    # Draw Menu Item Text
    ctx.color(colors.text)
    ctx.text(
      rect.x + self.metrics.minH,
      rect.y + fontsize shr 1 - metrics.desc, 
      self.label)
    
  proc event0(state: ptr GUIState): bool =
    # Remove Grab Flag
    self.flags.clear(wGrab)
    # Check if was actioned and execute ondone callback
    result = state.kind == evCursorRelease and self.test(wHover)
    if result and valid(self.ondone):
      push(self.ondone)

# ---------------
# Menu Item Kinds
# ---------------

widget GUIMenuCB of GUIMenuItem:
  attributes:
    cb: GUICallback

  new menuitem(label: string, cb: GUICallback):
    result.init0(label)
    result.cb = cb

  method event(state: ptr GUIState) =
    if self.event0(state) and valid(self.cb):
      push(self.cb)

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)

widget GUIMenuOption of GUIMenuItem:
  attributes:
    option: ptr int32
    expected: int32

  new menuoption(label: string, option: ptr int32, expected: int32):
    result.init0(label)
    result.option = option

  method event(state: ptr GUIState) =
    if self.event0(state):
      discard

widget GUIMenuCheck of GUIMenuItem:
  attributes:
    check: ptr bool

  new menucheck(label: string, check: ptr bool):
    result.init0(label)
    result.check = check

  method event(state: ptr GUIState) =
    if self.event0(state):
      discard

widget GUIMenuPopover of GUIMenuItem:
  attributes:
    popover: GUIWidget

  new menuitem(label: string, popover: GUIWidget):
    result.init0(label)
    result.popover = popover

  method event(state: ptr GUIState) =
    if self.event0(state):
      discard

# --------------
# GUI Menu Popup
# --------------

widget GUIMenu:
  attributes:
    label: string

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
      var metrics = addr widget.metrics
      if widget.vtable == self.vtable:
        discard # Warp into menuitem
        metrics = addr widget.metrics
      # Arrange Cursor
      let h = metrics.minH
      metrics.x = border
      metrics.y = border + y
      metrics.w = width
      metrics.h = h
      # Step Height
      y += h
    # Offset Border
    width += border shl 1
    y += border shl 1
    # Change Size if is a window
    block: #if self.kind in {wgPopup, wgMenu}:
      self.metrics.minW = width
      self.metrics.minH = y
      self.rect.w = width
      self.rect.h = y

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