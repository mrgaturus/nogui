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

widget GUIMenuItemPopup of GUIMenuItem:
  attributes: @public:
    popup: GUIWidget

  new menuitem(label: string, popup: GUIWidget):
    result.init0(label)
    result.popup = popup

  method event(state: ptr GUIState) =
    if self.event0(state):
      discard

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)
    # Draw Submenu Arrow
    let
      app = getApp()
      rect = rect self.rect
      desc = float32 app.font.desc
      minH = float32 self.metrics.minH shr 1
    # Fill Background
    ctx.color(app.colors.text)
    let
      p0 = point(rect.xw - minH, rect.y - desc - desc)
      p1 = point(rect.xw - minH, rect.yh + desc + desc)
      p2 = point(rect.xw + desc * 1.5, (rect.y + rect.yh) * 0.5)
    ctx.triangle(p0, p1, p2)

export GUIMenuItemPopup