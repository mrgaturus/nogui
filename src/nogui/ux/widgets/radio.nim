import ../prelude

widget GUIRadio:
  attributes:
    label: string
    # Radio Check
    expected: int32
    check: ptr int32

  new radio(label: string, expected: int32, check: ptr int32):
    let metrics = addr getApp().font
    # Set to Font Size Metrics
    result.minimum(0, metrics.height)
    # Widget Standard Flag
    result.flags = wMouse
    # Radio Button Attributes
    result.label = label
    result.expected = expected
    result.check = check

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
      # Locate Point
      r = rect.h shr 1
      p = point(rect.x + r, rect.y + r)
      # Circle Radious Size
      radius = float32(r)
    # Fill Radio Background
    ctx.color self.optionColor()
    ctx.circle(p, radius)
    # Set Text Color
    ctx.color(colors.text)
    # If Checked Draw Circle Mark
    if self.check[] == self.expected:
      ctx.circle(p, radius * 0.5)
    # Draw Text Next To Circle
    ctx.text( # Centered Vertically
      rect.x + rect.h + 4, 
      rect.y - app.font.desc,
      self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = self.expected
