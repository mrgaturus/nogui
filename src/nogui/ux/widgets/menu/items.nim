import base
# Use MenuItem Attributes
privateAccess(UXMenuItem)

# -----------------
# GUI Menu Callback
# -----------------

widget UXMenuItemCB of UXMenuItem:
  attributes:
    cb: GUICallback

  new menuitem(label: string, icon: CTXIconID, cb: GUICallback):
    result.init0(label, icon)
    result.cb = cb

  new menuitem(label: string, cb: GUICallback):
    result.init0(label)
    result.cb = cb

  method event(state: ptr GUIState) =
    if self.event0(state):
      send(self.cb)

  method draw(ctx: ptr CTXRender) =
    self.draw0(ctx)
    # Draw Label Icon
    let p = label(self.lm, self.rect)
    ctx.icon(self.icon, p.xi, p.yi)

# ---------------
# GUI Menu Option
# ---------------

widget UXMenuItemOption of UXMenuItem:
  attributes:
    option: & int32
    value: int32

  new menuoption(label: string, option: & int32, value: int32):
    result.init0(label)
    result.option = option
    result.value = value

  method event(state: ptr GUIState) =
    if self.event0(state):
      self.option.react[] = self.value

  method draw(ctx: ptr CTXRender) =
    self.draw0(ctx)
    # Locate Option Circle
    let
      lm = self.lm
      p = label(lm, self.rect)
      colors = addr getApp().colors
      # Locate Circle Center
      cp = point(
        p.xi + lm.icon shr 1,
        p.yi + lm.icon shr 1)
      # Radius Size
      r = float32(lm.icon) * 0.4
    # Highlight Color
    var color = colors.item
    if self.selected:
      color = colors.focus
    # Draw Check Square
    ctx.color(color)
    ctx.circle(cp, r)
    # If Checked Draw Circle Mark
    if self.option.peek[] == self.value:
      ctx.color getApp().colors.text
      ctx.circle(cp, r * 0.5)

# -----------------
# GUI Menu Checkbox
# -----------------

widget UXMenuItemCheck of UXMenuItem:
  attributes:
    check: & bool

  new menucheck(label: string, check: & bool):
    result.init0(label)
    result.check = check

  method event(state: ptr GUIState) =
    if self.event0(state):
      let check = self.check.react()
      check[] = not check[]

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)
    # Locate Check Square
    let
      lm = self.lm
      p = label(lm, self.rect)
      colors = addr getApp().colors
    # Locate Check Square
    var r = rect(p.xi, p.yi, lm.icon, lm.icon)
    # Highlight Color
    var color = colors.item
    if self.selected:
      color = colors.focus
    # Draw Check Square
    ctx.color(color)
    ctx.fill(r)
    # If Checked Draw Circle Mark
    if self.check.peek[]:
      let pad = float32(lm.icon shr 2)
      # Locate Marked Check
      r.x0 += pad; r.y0 += pad
      r.x1 -= pad; r.y1 -= pad
      # Draw Marked Check
      ctx.color getApp().colors.text
      ctx.fill(r)

# ----------------
# GUI Menu Popover
# ----------------

type UXMenuOpaque* = distinct GUIWidget
widget UXMenuItemPopup of UXMenuItem:
  attributes: {.public.}:
    popup: GUIWidget

  callback cbPopup:
    let 
      popup = self.popup
      rect = addr self.rect
    if self.slot[].current == self:
      popup.send(wsOpen)
      # Move Nearly to Menu
      let m = addr popup.metrics
      m.x = int16(rect.x + rect.w)
      m.y = int16(rect.y - 2)
    # Close Menu if Leaved
    else: popup.send(wsClose)

  new menuitem(label: string, popup: UXMenuOpaque):
    result.init0(label)
    result.popup = GUIWidget(popup)

  method draw(ctx: ptr CTXRender) =
    let r = extra(self.lm, self.rect)
    # Draw Menu and Arrow
    self.draw0(ctx)
    ctx.arrowRight(r)

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      getWindow().send(wsUngrab)

  method handle(reason: GUIHandle) =
    if reason == inHover:
      self.slot[].select(self, self.cbPopup)
