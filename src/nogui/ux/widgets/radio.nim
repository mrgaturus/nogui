import ../[prelude, labeling]

widget UXRadio:
  attributes:
    label: string
    lm: GUILabelMetrics
    # Radio Check
    expected: int32
    check: ptr int32

  new radio(label: string, expected: int32, check: ptr int32):
    result.flags = wMouse
    # RadioButton Attributes
    result.label = label
    result.expected = expected
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
    if self.check[] == self.expected:
      ctx.circle(pc, radius * 0.5)
    # Draw Text Next to Checkbox
    ctx.text(p.xt, p.yt, self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = self.expected
