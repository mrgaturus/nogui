import ../[prelude, labeling]

widget UXCheckBox:
  attributes:
    label: string
    lm: GUILabelMetrics
    # Checkbox Data
    check: & bool

  new checkbox(label: string, check: & bool):
    result.flags = {wMouse}
    # Checkbox Attributes
    result.label = label
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
      h = lm.icon
      # Label Position & Color
      p = left(self.lm, self.rect)
      col = getApp().colors.text
    # Checkbox Rect Location
    var r = rect(p.xi, p.yi, h, h)
    # Fill Checkbox Background
    ctx.color self.optionColor()
    ctx.fill(r)
    # Set Glyphs Color
    ctx.color(col)
    # Draw Mark if Checked
    if self.check.peek[]:
      let pad = float32(lm.icon shr 2)
      # Locate Marked Check
      r.x0 += pad; r.y0 += pad
      r.x1 -= pad; r.y1 -= pad
      # Adjust Rect Position
      ctx.fill(r)
    # Draw Text Next to Checkbox
    ctx.text(p.xt, p.yt, self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      let check = self.check.react()
      check[] = not check[]

# -----------------
# GUI Toggle Button
# -----------------

import button
# Define Toggle Button Widget
widget UXButtonCheck of UXButtonBase:
  attributes:
    check: & bool

  new button(label: string, check: & bool):
    result.init0(label, CTXIconEmpty)
    result.check = check

  new button(icon: CTXIconID, check: & bool):
    result.init0("", icon)
    result.check = check

  new button(label: string, icon: CTXIconID, check: & bool):
    result.init0(label, icon)
    result.check = check

  method draw(ctx: ptr CTXRender) =
    const colors = [btnClear, btnActive]
    let check = int32 self.check.peek[]
    # Draw Button Selected
    self.mode = colors[check]
    self.draw0(ctx)

  method event(state: ptr GUIState) =
    if self.event0(state):
      let check = self.check.react()
      check[] = not check[]
