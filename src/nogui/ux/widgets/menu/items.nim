import base

# -----------------
# GUI Menu Callback
# -----------------

widget UXMenuItemCB of UXMenuItem:
  attributes:
    cb: GUICallback

  new menuitem(label: string, cb: GUICallback):
    result.init0(label)
    result.cb = cb

  method event(state: ptr GUIState) =
    if self.event0(state) and valid(self.cb):
      push(self.cb)

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)

# ---------------
# GUI Menu Option
# ---------------

widget UXMenuItemOption of UXMenuItem:
  attributes:
    option: ptr int32
    expected: int32
    # Optional Callback
    @public:
      cb: GUICallback

  new menuoption(label: string, option: ptr int32, expected: int32):
    result.init0(label)
    result.option = option

  method event(state: ptr GUIState) =
    if self.event0(state):
      self.option[] = self.expected
      # Execute Callback
      if valid(self.cb):
        push(self.cb)

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)

# -----------------
# GUI Menu Checkbox
# -----------------

widget UXMenuItemCheck of UXMenuItem:
  attributes:
    check: ptr bool
    # Optional Callback
    @public:
      cb: GUICallback

  new menucheck(label: string, check: ptr bool):
    result.init0(label)
    result.check = check

  method event(state: ptr GUIState) =
    if self.event0(state):
      self.check[] = not self.check[]
      # Execute Callback
      if valid(self.cb):
        push(self.cb)

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)

# ----------------
# GUI Menu Popover
# ----------------

type UXMenuOpaque* = distinct GUIWidget
widget UXMenuItemPopup of UXMenuItem:
  attributes: @public:
    popup: GUIWidget

  callback popupCB:
    let 
      popup = self.popup
      rect = addr self.rect
    if self.portal[] == self:
      popup.open()
      # Move Nearly to Menu
      popup.move(rect.x + rect.w, rect.y - 2)
    else: popup.close()

  new menuitem(label: string, popup: UXMenuOpaque):
    result.init0(label)
    result.popup = GUIWidget(popup)
    result.onportal = result.popupCB

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = rect self.rect
      colors = addr app.colors
      r = extra(self.lm, self.rect)
    # Fill Selected Background
    if not self.test(wHover) and self.portal[] == self:
      ctx.color colors.item
      ctx.fill rect
    # Draw Menu Label
    self.draw0(ctx)
    ctx.arrowRight(r)

  method event(state: ptr GUIState) =
    discard

export UXMenuItemPopup