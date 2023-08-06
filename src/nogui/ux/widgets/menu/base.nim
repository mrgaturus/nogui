import ../../prelude

# --------------------------------
# TODO: Move this to widget module
# --------------------------------

# TODO: Move to widget module
proc fit*(self: GUIWidget, w, h: int32) =
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

# ------------------
# GUI Menu Item Base
# ------------------

widget GUIMenuItem:
  attributes:
    label: string
    @public:
      [ondone, onportal]: GUICallback
      portal: ptr GUIMenuItem

  proc select() =
    if isNil(self.portal):
      return
    # Notify Prev Portal
    let prev = self.portal[]
    if not isNil(prev) and valid(prev.onportal):
      push(prev.onportal)
    # Notify Self Portal
    if valid(self.onportal):
      push(self.onportal)
    # Change Portal
    self.portal[] = self

  proc init0*(label: string) =
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

  proc draw0*(ctx: ptr CTXRender) =
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
    
  proc event0*(state: ptr GUIState): bool =
    # Remove Grab Flag
    self.flags.clear(wGrab)
    # Check if was actioned and execute ondone callback
    result = state.kind == evCursorRelease and self.test(wHover)
    if result and valid(self.ondone):
      push(self.ondone)

  method handle(kind: GUIHandle) =
    if kind in {inHover, inFocus}:
      self.select()

# Export Widget Inheritable
export GUIMenuItem, prelude
