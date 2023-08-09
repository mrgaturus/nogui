import menu, menu/base
import std/importutils
from ../../builder import controller
# TODO: export type also
import button {.all.}

# -------------
# Combobox Item
# -------------

widget GUIComboItem of GUIMenuItem:
  attributes:
    value: int
    # Portal to ComboModel
    selected: ptr GUIComboItem

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
    menu: GUIMenu
    selected: GUIComboItem
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
    var found: GUIComboItem
    # Find in Cache Captures
    for w in self.flatten:
      let item {.cursor.} = cast[GUIComboItem](w)
      if item.value == value:
        found = item
        break
    # Replace Found
    assert not isNil(found)
    self.selected = found

  proc configure(menu: GUIMenu) =
    let portal = addr self.selected
    # Configure Menu Items
    for w in forward(menu.first):
      if w of GUIComboItem:
        # Bind With Selected Model and Capture Cache
        cast[GUIComboItem](w).selected = portal
        self.flatten.add cast[pointer](w)
      elif w of GUIMenu:
        # Recursive search
        self.configure(w.GUIMenu)

  proc `menu=`*(menu: GUIMenu) =
    privateAccess(GUIMenu)
    # Replace Menu Callback
    self.ondone = menu.cbClose
    menu.cbClose = self.cbMenuDone
    # Configure Menu
    self.flatten = newSeq[pointer](0)
    self.configure(menu)
    # Select First Item of Flatten Cache
    self.selected = cast[GUIComboItem](self.flatten[0])
    self.menu = menu

  new combomodel(menu: GUIMenu):
    `menu=`(result, menu)

# ------------
# GUI Combobox
# ------------

widget GUIComboBox of GUIButton:
  attributes:
    model: ComboModel

  callback cbOpenMenu:
    let 
      rect = addr self.rect
      menu {.cursor.} = self.model.menu
    # Re-Open Menu
    if menu.test(wVisible):
      menu.close()
    menu.open()
    # Open Menu to Combobox
    menu.move(rect.x - 2, rect.y + rect.h + 2)
    menu.metrics.w = int16 rect.w

  new combobox(model: ComboModel):
    privateAccess(GUIButton)
    # Configure Combobox Metrics
    let metrics = addr getApp().font
    result.minimum(0, metrics.height - metrics.desc)
    # Configure Button
    result.flags = wMouse
    result.model = model
    result.cb = result.cbOpenMenu

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
      metrics = addr app.font
      # Text Center Offset
      s {.cursor.} = self.model.selected
    # Allow Private of MenuItem
    privateAccess(GUIMenuItem)
    # Select Color State
    ctx.color self.itemColor()
    ctx.fill rect(self.rect)
    # Put Combobox Text
    ctx.color(colors.text)
    ctx.text( # Draw Centered Text
      rect.x + metrics.size, 
      rect.y + metrics.asc shr 1, s.label)

export ComboModel