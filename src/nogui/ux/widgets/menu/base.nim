import ../../[prelude, labeling]
export prelude, labeling

# ------------------
# GUI Menu Item Slot
# ------------------

type
  UXMenuSlot* = object
    item {.cursor.}: GUIWidget
    # Slot Callbacks
    ondone*: GUICallback
    onslot*: GUICallback

proc current*(slot: UXMenuSlot): GUIWidget =
  slot.item

proc select*(slot: var UXMenuSlot, item: GUIWidget) =
  if slot.item == item: return
  slot.item = item
  # Consume Slot Callback
  send(slot.onslot)
  slot.onslot = default(GUICallback)

proc select*(slot: var UXMenuSlot, item: GUIWidget, cb: GUICallback) =
  slot.select(item)
  # Send Changed Callback
  slot.onslot = cb
  cb.send()

proc unselect*(slot: var UXMenuSlot) {.inline.} =
  slot.select(nil)

# ------------------
# GUI Menu Item Base
# ------------------

widget UXMenuItem:
  attributes:
    label: string
    icon: CTXIconID
    lm: GUIMenuMetrics
    # Menu Selected Slot
    {.public.}:
      slot: ptr UXMenuSlot

  proc selected*: bool {.inline.} =
    self.test(wHover) or self.slot[].current == self

  proc init0*(label: string, icon = CTXIconEmpty) =
    self.flags = {wMouse}
    # Labeling Attributes
    self.icon = icon
    self.label = label

  proc draw0*(ctx: ptr CTXRender) =
    let
      colors = addr getApp().colors
      rect = addr self.rect
      p = label(self.lm, self.rect)
    # Fill Menu Item Highlight
    if self.selected:
      ctx.color colors.item
      ctx.fill rect rect[]
    # Draw Menu Item Text
    ctx.color(colors.text)
    ctx.text(p.xt, p.yt, self.label)

  proc event0*(state: ptr GUIState): bool =
    if state.kind == evCursorClick:
      getWindow().send(wsUnGrab)
    # Check if was Clicked and Send ondone Callback
    result = state.kind == evCursorRelease and self.test(wHover)
    if result: send(self.slot.ondone)

  method update =
    let
      m = addr self.metrics
      # Application Padding
      pad0 = getApp().space.pad
      pad1 = pad0 shl 1
      # Calculate Label Metrics
      lm = metricsMenu(self.label, self.icon)
    # Change Min Size
    m.minW = lm.width + pad1
    m.minH = lm.h + pad0
    # Change Label Metrics
    self.lm = lm

  method handle(reason: GUIHandle) =
    let slot = self.slot
    if reason == inHover:
      slot[].select(self)
    elif reason == outHover:
      slot[].unselect()

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
    rect.y0 = (rect.y0 + rect.y1) * 0.5 - 1
    rect.y1 = rect.y0 + 2
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
      app = getApp()
      # Application Padding
      pad0 = app.space.pad
      pad1 = pad0 shl 1
      # Font Width
      m = addr self.metrics
      w = int16 width(self.label)
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
      # Center Y Offset
      oy = font.baseline
    # Opacity Constants
    const 
      cAlpha = 0x7FFFFFFF'u32
      cText = 0xB0FFFFFF'u32
    # Create Rect
    ctx.color(colors.item and cAlpha)
    ctx.fill rect rect[]
    # Draw Text Centered
    ctx.color(colors.text and cText)
    ctx.text(
      rect.x + oy,
      rect.y + (rect.h - oy) shr 1, 
      self.label)
