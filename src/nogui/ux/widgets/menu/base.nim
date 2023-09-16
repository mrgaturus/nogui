import ../../[prelude, labeling]

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

widget UXMenuSeparator:
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

widget UXMenuSeparatorLabel:
  attributes:
    label: string

  new menuseparator(label: string):
    # Set Separator Label
    result.label = label

  method update =
    let
      # TODO: allow customize margin
      font = addr getApp().font
      pad0 = font.asc shr 1
      pad1 = pad0 shl 1
      # Font Width
      m = addr self.metrics
      w = int16 width(self.label)
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
      ox = self.metrics.minW - font.asc
      oy = font.height - font.baseline
    # Create Rect
    ctx.color(colors.item and 0x7FFFFFFF)
    ctx.fill rect rect[]
    # Draw Text Centered
    ctx.color(colors.text)
    ctx.text(
      rect.x + (rect.w - ox) shr 1,
      rect.y + (rect.h - oy) shr 1, 
      self.label)

# ------------------
# GUI Menu Item Base
# ------------------

widget UXMenuItem:
  attributes:
    label: string
    icon: CTXIconID
    # Menu Item Actions
    @public:
      lm: GUIMenuMetrics
      [ondone, onportal]: GUICallback
      portal: ptr UXMenuItem

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

  proc init0*(label: string, icon = CTXIconEmpty) =
    self.flags = wMouseKeyboard
    # Labeling Attributes
    self.icon = icon
    self.label = label

  proc draw0*(ctx: ptr CTXRender) =
    let
      colors = addr getApp().colors
      rect = addr self.rect
      p = label(self.lm, self.rect)
    # Fill Background
    if self.test(wHover):
      ctx.color colors.item
      ctx.fill rect rect[]
    # Draw Menu Item Text
    ctx.color(colors.text)
    ctx.text(p.xt, p.yt, self.label)
    
  proc event0*(state: ptr GUIState): bool =
    # Remove Grab Flag
    self.flags.clear(wGrab)
    # Check if was actioned and execute ondone callback
    result = state.kind == evCursorRelease and self.test(wHover)
    if result and valid(self.ondone):
      push(self.ondone)

  method update =
    let
      m = addr self.metrics
      # TODO: allow customize margin
      pad0 = getApp().font.asc shr 1
      pad1 = pad0 shl 1
      # Calculate Label Metrics
      lm = metricsMenu(self.label, self.icon)
    # Change Min Size
    m.minW = lm.width + pad1
    m.minH = lm.h + pad0
    # Change Label Metrics
    self.lm = lm

  method handle(kind: GUIHandle) =
    if kind in {inHover, inFocus}:
      self.select()

# Export Widget Inheritable
export UXMenuItem, prelude, labeling
