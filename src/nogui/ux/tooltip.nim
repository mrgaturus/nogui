import ../core/shortcut
import widgets/label
import prelude

# -------------------
# UX Tooltip Toplevel
# -------------------

widget UXTooltipFrame:
  attributes:
    fixed: bool
    {.cursor.}:
      info: GUIWidget
    # Tooltip Cursor Observer
    watchdog: GUIObserver

  callback cbCursor:
    if not self.fixed:
      self.send(wsLayout)

  new tooltipframe(info: GUIWidget, fixed = false):
    result.kind = wkTooltip
    result.fixed = fixed
    # Create Mouse Observer
    let dog = observer(result.cbCursor, {evCursorMove})
    result.watchdog = dog
    # Add Tooltip Content
    result.info = info
    result.add(info)

  method update =
    let
      app = getApp()
      clip = getWindow().rect
      mx = int16 app.state.mx
      my = int16 app.state.my
      # Tooltip Metrics
      m0 = addr self.metrics
      m1 = addr self.info.metrics
      # Border and Padding
      s = addr app.space
      pad = (s.line + s.pad) shl 1
    # Copy Metrics Dimensions
    m0.minW = m1.minW + pad
    m0.minH = m1.minH + pad
    m0.w = m0.minW
    m0.h = m0.minH
    # Locate Tooltip Center-Top
    m0.x = mx - m0.w shr 1
    m0.y = my - m0.h - s.pad
    # Swep Tooltip to Window Boundaries
    if m0.y < 0: m0.y = my + app.font.height + s.pad
    m0[].swep(int16 clip.w, int16 clip.h)

  method layout =
    let
      s = addr getApp().space
      pad = s.line + s.pad
      # Widget Metrics
      m0 = addr self.metrics
      m1 = addr self.info.metrics
    # Inset Element
    m1[].fit m0[]
    m1[].inset(pad)

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      colors = app.colors
      border = app.space.line
      # Widget Rect
      r = rect(self.rect)
    # Fill Tooltip Frame
    ctx.color(colors.darker)
    ctx.line(r, float32 border)
    ctx.color(colors.panel and 0xEFFFFFFF'u32)
    ctx.fill(r)

  method handle(reason: GUIHandle) =
    if reason == inFrame:
      # Register Cursor Observer
      let obs = getWindow().observers
      obs[].register(self.watchdog)
    elif reason == outFrame:
      unregister(self.watchdog)

# -----------------
# UX Tooltip Manager
# -----------------

widget UXTooltipDummy:
  new dummy():
    discard

controller UXTooltipManager:
  attributes:
    frame: UXTooltipFrame
    dummy: UXTooltipDummy
    # Current Tooltip
    {.cursor.}:
      tip: UXTooltipFrame
    # Visible Check
    visible: bool

  proc replace(info: GUIWidget) =
    let frame = self.frame
    # Replace Tooltip Frame Info
    if frame.info != info:
      replace(frame.info, info)
      frame.info = info  

  callback showTooltip:
    if not isNil(self.tip):
      send(self.tip, wsOpen)
      self.visible = true

  callback hideTooltip:
    if not isNil(self.tip):
      send(self.tip, wsClose)
      self.tip = nil
    # Clear Current Tooltip
    self.replace(self.dummy)
    self.visible = false

  new tooltipmanager():
    let dummy = dummy()
    # Define Default Tooltip Frame
    result.dummy = dummy
    result.frame = tooltipframe(dummy)

  proc show*(frame: UXTooltipFrame) =
    if isNil(self.tip):
      timeout(self.showTooltip, 500)
    elif self.visible:
      send(self.tip, wsClose)
      send(frame, wsOpen)
    # Set Tooltip
    timestop(self.hideTooltip)
    self.tip = frame

  proc show*(info: GUIWidget) =
    var frame = self.frame
    self.replace(info)
    self.show(frame)

  proc hide*() =
    timeout(self.hideTooltip, 250)

var tipman: UXTooltipManager
proc getTooltipManager*(): UXTooltipManager =
  if isNil(tipman):
    tipman = tooltipmanager()
  # Return Global Manager
  result = tipman

# --------------------
# UX Tooltip Forwarder
# --------------------

widget UXTooltip:
  attributes:
    info: GUIWidget
    # Widget Wrapping
    {.cursor.}:
      widget: GUIWidget
    # Tooltip Properties
    {.public.}:
      fixed: bool

  proc init(widget: GUIWidget) =
    self.kind = wkForward
    self.flags = {wMouse}
    # Define Widget Target
    self.widget = widget
    self.add(widget)

  new tooltip(text: string, widget: GUIWidget):
    result.init(widget)
    result.info = label(text, hoMiddle, veMiddle)

  new tooltip(info: GUIWidget, widget: GUIWidget):
    result.init(widget)
    result.info = info

  method update =
    let
      m0 = addr self.metrics
      m1 = addr self.widget.metrics
    # Copy Minimum Size
    m0[].minfit m1[]

  method layout =
    let
      m0 = addr self.metrics
      m1 = addr self.widget.metrics
    # Copy Minimum Size
    m1[].fit m0[]

  method handle(reason: GUIHandle) =
    let tips = getTooltipManager()
    if reason == inHover:
      tips.show(self.info)
    elif reason == outHover:
      tips.hide()
