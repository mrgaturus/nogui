import ../[prelude, labeling]

widget UXRadio:
  attributes:
    label: string
    lm: GUILabelMetrics
    # Radio Check
    value: int32
    check: & int32

  new radio(label: string, value: int32, check: & int32):
    result.flags = {wMouse}
    result.label = label
    # Radio Attributes
    result.value = value
    result.check = check

  method update =
    let
      m = addr self.metrics
      lm = metricsOption(self.label)
    # Set Minimun Size
    m.minW = lm.w
    m.minH = lm.h
    # Set Label Metrics
    self.lm = lm

  method draw(ctx: ptr CTXRender) =
    let
      lm = self.lm
      # Label Position & Color
      p = left(self.lm, self.rect)
      col = getApp().colors.text
      # Center Point
      r = lm.icon shr 1
      pc = point(p.xi + r, p.yi + r)
      radius = float32(r) - 0.5
    # Fill Checkbox Circle
    ctx.color self.optionColor()
    ctx.circle(pc, radius)
    # Set Glyphs Color
    ctx.color(col)
    # If Checked Draw Circle Mark
    if self.check.peek[] == self.value:
      ctx.circle(pc, radius * 0.5)
    # Draw Text Next to Checkbox
    ctx.text(p.xt, p.yt, self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check.react[] = self.value

# -----------------
# GUI Option Button
# -----------------

import button
# Define Toggle Button Widget
widget UXButtonOption of UXButtonBase:
  attributes:
    value: int32
    check: & int32

  new button(label: string, icon: CTXIconID, check: & int32, value: int32):
    result.init0(label, icon)
    # Set Checkbox Attribute
    result.value = value
    result.check = check

  new button(icon: CTXIconID, check: & int32, value: int32):
    result.init0("", icon)
    # Set Checkbox Attribute
    result.value = value
    result.check = check

  new button(label: string, check: & int32, value: int32):
    result.init0(label, CTXIconEmpty)
    # Set Checkbox Attribute
    result.value = value
    result.check = check

  method draw(ctx: ptr CTXRender) =
    const colors = [btnClear, btnActive]
    let check = self.check.peek[] == self.value
    # Draw Button Selected
    self.mode = colors[int32 check]
    self.draw0(ctx)

  method event(state: ptr GUIState) =
    if self.event0(state):
      self.check.react[] = self.value
