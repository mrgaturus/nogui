import base

# ------------------
# GUI Menu Bar Popup
# ------------------

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