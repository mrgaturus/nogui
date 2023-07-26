import ../prelude

widget GUIRadio:
  attributes:
    label: string
    expected: byte
    check: ptr byte

  new radio(label: string, expected: byte, check: ptr byte):
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
    # Select Color State
    ctx.color: 
      if not self.any(wHoverGrab):
        colors.item
      elif self.test(wHoverGrab):
        colors.clicked
      else: colors.focus
    # Fill Radio Background
    ctx.circle point(
      rect.x, rect.y),
      float32(rect.h shr 1)
    # If Checked Draw Circle Mark
    if self.check[] == self.expected:
      ctx.color(colors.text)
      ctx.circle point(
        rect.x + 4, rect.y + 4),
        float32(rect.h shr 1 - 4)
    # Draw Text Next To Circle
    ctx.color(colors.text)
    ctx.text( # Centered Vertically
      rect.x + rect.h + 4, 
      rect.y - app.font.desc,
      self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = self.expected
