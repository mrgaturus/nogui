import ../prelude

widget GUICheckBox:
  attributes:
    label: string
    check: ptr bool

  new checkbox(label: string, check: ptr bool):
    let app = getApp()
    # Set to Font Size Metrics
    result.minimum(0, app.font.height)
    # Button Attributes
    result.flags = wMouse
    result.label = label
    result.check = check

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
    # Select Color State
    ctx.color self.itemColor()
    # Fill Checkbox Background
    ctx.fill rect(
      rect.x, rect.y,
      rect.h, rect.h)
    # If Checked, Draw Mark
    if self.check[]:
      ctx.color(colors.text)
      ctx.fill rect(
        rect.x + 4, rect.y + 4,
        rect.h - 8, rect.h - 8)
    # Draw Text Next to Checkbox
    ctx.color(colors.text)
    ctx.text( # Centered Vertically
      rect.x + rect.h + 4, 
      rect.y - app.font.desc,
      self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = not self.check[]
