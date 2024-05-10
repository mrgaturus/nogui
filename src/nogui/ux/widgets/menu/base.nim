import ../../[prelude, labeling]
export prelude, labeling

type
  UXMenuPivotMode = enum
    menuHorizontal
    menuVerticalSimple
    menuVerticalClip
  UXMenuPivot* = object
    x*, y*: int32
    ox*, oy*: int32
    # Vertical Location
    mode*: UXMenuPivotMode
  # Menu Popup Mapping
  UXMenuOpaque* = distinct GUIWidget
  UXMenuMapper* = object
    menu*: GUIWidget
    # Pivot Handling
    pivot*: UXMenuPivot
    cb*: GUICallbackEX[UXMenuPivot]
  # Menu Selected Slot
  UXMenuSlot* = object
    item {.cursor.}: GUIWidget
    # Slot Callbacks
    ondone*: GUICallback
    onslot*: GUICallback

# ---------------------
# GUI Menu Pivot Helper
# ---------------------

proc locate*(pivot: var UXMenuPivot, rect: GUIRect) =
  if pivot.mode >= menuVerticalSimple:
    pivot.x = rect.x
    pivot.y = rect.y + rect.h
    # Alternative Pivot
    pivot.ox = pivot.x
    pivot.oy = rect.y
  # Horizontal Pivot Location
  elif pivot.mode == menuHorizontal:
    pivot.x = rect.x + rect.w
    pivot.y = rect.y
    # Alternative Pivot
    pivot.ox = rect.x
    pivot.oy = pivot.y

proc locate*(pivot: var UXMenuPivot, x, y: int32) =
  pivot.x = x
  pivot.y = y
  # Alternative Pivot
  pivot.ox = x
  pivot.oy = y

proc swep(rect: var GUIRect, clip: GUIRect) =
  rect.x -= max(rect.x + rect.w - clip.w, 0)
  rect.y -= max(rect.y + rect.h - clip.h, 0)
  rect.x = max(rect.x, 0)
  rect.y = max(rect.y, 0)
  # Trim Vertical Dimension
  rect.h -= max(rect.y + rect.h - clip.h, 0)

proc apply*(self: GUIWidget, pivot: UXMenuPivot) =
  let
    clip = getWindow().rect
    m = addr self.metrics
  # Location Rect
  assert self.kind == wkPopup
  var rect = GUIRect(w: m.w, h: m.h)
  # Locate Pivot Point
  rect.x = pivot.x
  rect.y = pivot.y
  # Handle Pivot Clipping
  case pivot.mode
  of menuHorizontal:
    if rect.x + rect.w > clip.w:
      rect.x = pivot.ox - rect.w
  of menuVerticalSimple, menuVerticalClip:
    let rect0 = rect
    rect.y = pivot.oy - rect.h
    if rect.y < clip.h - (rect.y + rect.h):
      rect = rect0
    # Avoid Swep Clipping First
    if pivot.mode == menuVerticalClip:
      rect = intersect(rect, clip)
      rect.x = rect0.x
      rect.w = rect0.w
  # Swep Rect to Clip
  rect.swep(clip)
  # Replace Metrics
  m.x = int16(rect.x)
  m.y = int16(rect.y)
  m.w = int16(rect.w)
  m.h = int16(rect.h)

# ---------------
# GUI Menu Mapper
# ---------------

proc open*(map: var UXMenuMapper) =
  let menu {.cursor.} = map.menu
  # Open Popup Menu
  if not menu.test(wVisible):
    send(map.cb, map.pivot)
    menu.send(wsOpen)

proc close*(map: var UXMenuMapper) =
  let menu {.cursor.} = map.menu
  if menu.test(wVisible):
    menu.send(wsClose)

proc update*(map: var UXMenuMapper) =
  if map.menu.test(wVisible):
    send(map.cb, map.pivot)

proc locate*(map: var UXMenuMapper, rect: GUIRect) =
  map.pivot.locate(rect)
  map.update()

# ------------------
# GUI Menu Item Slot
# ------------------

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
