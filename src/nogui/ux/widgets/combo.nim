import menu, menu/base
import std/importutils
from ../../builder import controller
# Menu Item Attributes
privateAccess(UXMenuItem)

# -----------------
# Combobox Selected
# -----------------

type
  ComboValue = object
    value*: int
    # Labeling Info
    label: string
    icon: CTXIconID
    lm: GUIMenuMetrics

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
    var labeling = metricsMenu(self.label, self.icon)
    # Remove Offset if Empty Icon
    if self.icon == CTXIconEmpty:
      labeling.w -= self.lm.icon
    # Return Combo Value Info
    ComboValue(
      value: self.value,
      icon: self.icon,
      label: self.label,
      lm: labeling)

  method draw(ctx: ptr CTXRender) =
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
    # Selected Value
    selected: ComboValue
    flatten: seq[pointer]
    # User Defined Callback
    ondone: GUICallback
    {.public.}: onchange: GUICallback

  callback cbMenuDone:
    close(self.menu)
    # Send User Defined Callback
    if valid(self.onchange):
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
    assert not isNil(found)
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

widget GUIComboBox:
  attributes:
    model: ComboModel

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
    result.flags = wMouse
    result.model = model

  method update =
    let # Calculate Label Metrics
      font = addr getApp().font
      m = addr self.metrics
      size = font.height
      # TODO: allow customize margin
      pad0 = font.asc shr 1
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
    # Fill Background Color
    ctx.color self.itemColor()
    ctx.fill rect(self.rect)
    ctx.color getApp().colors.text
    # Draw Icon And Label
    ctx.icon(s.icon, p.xi, p.yi)
    ctx.text(p.xt, p.yt, s.label)
    # Draw Combobox Arrow
    ctx.arrowDown(ex)

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      self.flags.clear(wGrab)
      push(self.cbOpenMenu)
