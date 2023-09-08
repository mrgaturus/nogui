import menu, menu/base
import std/importutils
from ../../builder import controller

# -------------
# Combobox Item
# -------------

widget UXComboItem of UXMenuItem:
  attributes:
    value: int
    # Portal to ComboModel
    selected: ptr UXComboItem

  new comboitem(label: string, value: int):
    result.init0(label)
    result.value = value

  method draw(ctx: ptr CTXRender) =
    self.draw0(ctx)

  method event(state: ptr GUIState) =
    # Change Selected
    if self.event0(state):
      self.selected[] = self

# -------------------
# GUI Combobox Portal
# -------------------

controller ComboModel:
  attributes:
    menu: UXMenu
    selected: UXComboItem
    flatten: seq[pointer]
    # User Defined Callback
    ondone: GUICallback
    @public: onchange: GUICallback

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
    self.selected = found

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
    # Select First Item of Flatten Cache
    self.selected = cast[UXComboItem](self.flatten[0])
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
    # Configure Combobox Metrics
    let metrics = addr getApp().font
    result.minimum(0, metrics.height - metrics.desc)
    # Configure Button
    result.flags = wMouse
    result.model = model

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
      metrics = addr app.font
      # Text Center Offset
      s {.cursor.} = self.model.selected
    # Region Cursor
    var r = rect(self.rect)
    # Allow Private of MenuItem
    privateAccess(UXMenuItem)
    # Select Color State
    ctx.color self.itemColor()
    ctx.fill r
    # Put Combobox Text
    ctx.color(colors.text)
    ctx.text( # Draw Centered Text
      rect.x + metrics.size, 
      rect.y + metrics.asc shr 1, s.label)
    # Draw Triangle
    r.xw -= float32 metrics.asc shr 1
    r.yh -= float32 metrics.asc shr 1
    r.x = r.xw - float32 metrics.size
    r.y = r.yh - float32 metrics.size - metrics.asc shr 2
    # Triangle
    ctx.triangle(
      point((r.x + r.xw) * 0.5, r.yh),
      point(r.xw, r.y),
      point(r.x, r.y),      
    )

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      self.flags.clear(wGrab)
      push(self.cbOpenMenu)

export ComboModel