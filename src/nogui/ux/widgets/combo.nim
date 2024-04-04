import menu, menu/base
from ../../builder import controller
# Menu Item Attributes
privateAccess(UXMenuItem)

# -----------------------
# Combobox Selected Value
# -----------------------

type
  ComboValue* = object
    value*: int
    # Labeling Info
    label: string
    icon: CTXIconID
    # Labeling Metrics
    lm: GUIMenuMetrics

proc combovalue*(label: string, icon: CTXIconID, value: int): ComboValue =
  result.value = value
  result.label = label
  result.icon = icon
  # Calculate Label Metrics
  result.lm = metricsMenu(label, icon)
  if icon == CTXIconEmpty:
    result.lm.w -= result.lm.icon

# -------------
# Combobox Item
# -------------

widget UXComboItem of UXMenuItem:
  attributes:
    value: int
    # Portal to ComboModel
    selected: ptr ComboValue

  new comboitem(label: string, value: int):
    result.init0(label)
    result.value = value

  new comboitem(label: string, icon: CTXIconID, value: int):
    result.init0(label, icon)
    result.value = value

  proc combovalue: ComboValue =
    combovalue(self.label, self.icon, self.value)

  method draw(ctx: ptr CTXRender) =
    # Draw Background if Selected
    if self.selected[].value == self.value:
      ctx.color getApp().colors.darker
      ctx.fill rect(self.rect)
    # Draw Menu Handle
    self.draw0(ctx)
    # Draw Label Icon
    let p = label(self.lm, self.rect)
    ctx.icon(self.icon, p.xi, p.yi)

  method event(state: ptr GUIState) =
    # Change Selected Combovalue
    if self.event0(state):
      self.selected[] = self.combovalue

# -------------------
# GUI Combobox Portal
# -------------------

controller ComboModel:
  attributes:
    menu: UXMenu
    flatten: seq[pointer]
    ondone: GUICallback
    # Usable Data
    {.public.}: 
      selected: ComboValue
      onchange: GUICallback

  callback cbMenuDone:
    close(self.menu)
    # Send User Defined Callback
    push(self.onchange)

  proc select*(value: int) =
    var found: UXComboItem
    # Find in Cache Captures
    for w in self.flatten:
      let item {.cursor.} = cast[UXComboItem](w)
      if item.value == value:
        found = item
        break
    # Replace Found
    if not isNil(found):
      self.selected = found.combovalue

  proc configure(menu: UXMenu) =
    let portal = addr self.selected
    # Configure Menu Items
    for w in forward(menu.first):
      if w of UXComboItem:
        # Bind With Selected Model and Capture Cache
        cast[UXComboItem](w).selected = portal
        self.flatten.add cast[pointer](w)
      elif w of UXMenu:
        # Recursive search
        self.configure(w.UXMenu)

  proc `menu=`*(menu: UXMenu) =
    privateAccess(UXMenu)
    # Replace Menu Callback
    self.ondone = menu.cbClose
    menu.cbClose = self.cbMenuDone
    menu.kind = wgPopup
    # Configure Menu
    self.flatten = newSeq[pointer](0)
    self.configure(menu)
    # Select First Item and Get Combovalue
    let peek = cast[UXComboItem](self.flatten[0])
    self.selected = peek.combovalue
    self.menu = menu

  new combomodel(menu: UXMenu):
    `menu=`(result, menu)

# ------------
# GUI Combobox
# ------------

widget UXComboBox:
  attributes:
    model: ComboModel
    opaque: bool

  callback cbOpenMenu:
    let 
      rect = addr self.rect
      menu {.cursor.} = self.model.menu
    # Close Menu if Visible
    if menu.test(wVisible):
      menu.close()
    menu.open()
    # Open Menu to Combobox
    menu.move(rect.x, rect.y + rect.h + 2)
    menu.metrics.w = int16 rect.w

  new combobox(model: ComboModel):
    result.flags = {wMouse}
    result.model = model

  proc opaque*: UXComboBox {.inline.} =
    self.opaque = true; self

  method update =
    let
      app = getApp()
      # Font Metrics
      font = addr app.font
      m = addr self.metrics
      size = font.height
      # Application Padding
      pad0 = app.space.pad
      pad1 = pad0 shl 1
    # Change Min Size
    m.minW = size + pad1
    m.minH = size + pad0

  method draw(ctx: ptr CTXRender) =
    let 
      s = addr self.model.selected
      ex = extra(s.lm, self.rect)
    # Labeling Position
    var p = label(s.lm, self.rect)
    # Decide Current Color
    let bgColor = if not self.opaque:
      self.itemColor()
    else: self.opaqueColor()
    # Fill Background Color
    ctx.color bgColor
    ctx.fill rect(self.rect)
    ctx.color getApp().colors.text
    # Draw Icon And Label
    ctx.icon(s.icon, p.xi, p.yi)
    ctx.text(p.xt, p.yt, s.label)
    # Draw Combobox Arrow
    ctx.arrowDown(ex)

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      self.flags.excl(wGrab)
      push(self.cbOpenMenu)
