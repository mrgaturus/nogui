import base

# -----------------
# GUI Menu Callback
# -----------------

widget GUIMenuItemCB of GUIMenuItem:
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

widget GUIMenuItemOption of GUIMenuItem:
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

widget GUIMenuItemCheck of GUIMenuItem:
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

type GUIMenuOpaque* = distinct GUIWidget
widget GUIMenuItemPopup of GUIMenuItem:
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

  new menuitem(label: string, popup: GUIMenuOpaque):
    result.init0(label)
    result.popup = GUIWidget(popup)
    result.onportal = result.popupCB

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = rect self.rect
      colors = addr app.colors
      desc = float32 app.font.desc
      minH = float32 self.metrics.minH shr 1
    # Fill Selected Background
    if not self.test(wHover) and self.portal[] == self:
      ctx.color colors.item
      ctx.fill rect
    # Draw Menu Label
    self.draw0(ctx)
    # Fill Background
    ctx.color(colors.text)
    let
      p0 = point(rect.xw - minH, rect.y - desc - desc)
      p1 = point(rect.xw - minH, rect.yh + desc + desc)
      p2 = point(rect.xw + desc * 1.5, (rect.y + rect.yh) * 0.5)
    ctx.triangle(p0, p1, p2)

  method event(state: ptr GUIState) =
    discard

export GUIMenuItemPopup