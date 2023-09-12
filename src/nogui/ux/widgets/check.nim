import ../[prelude, labeling]

widget UXCheckBox:
  attributes:
    label: string
    lm: GUILabelMetrics
    # Checkbox Data
    check: ptr bool

  new checkbox(label: string, check: ptr bool):
    result.flags = wMouse
    # Checkbox Attributes
    result.label = label
    result.check = check

  method update =
    let 
      m = addr self.metrics
      lm = metrics(self.label)
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
    if self.check[]:
      let pad = float32(lm.icon shr 2)
      # Locate Marked Check
      r.x += pad; r.y += pad
      r.xw -= pad; r.yh -= pad
      # Adjust Rect Position
      ctx.fill(r)
    # Draw Text Next to Checkbox
    ctx.text(p.xt, p.yt, self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = not self.check[]

# -----------------
# GUI Toggle Button
# -----------------

import button
# Define Toggle Button Widget
widget UXButtonCheck of UXButtonOpaque:
  attributes:
    check: ptr bool

  new button(label: string, check: ptr bool):
    result.init0(label)
    # Set Checkbox Attribute
    result.check = check

  new button(icon: CTXIconID, label: string, check: ptr bool):
    result.init0(label, icon)
    # Set Checkbox Attribute
    result.check = check

  method draw(ctx: ptr CTXRender) =
    self.draw0(ctx, self.check[])

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = not self.check[]
