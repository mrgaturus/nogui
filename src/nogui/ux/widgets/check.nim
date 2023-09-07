import ../prelude

widget UXCheckBox:
  attributes:
    label: string
    check: ptr bool

  new checkbox(label: string, check: ptr bool):
    let 
      app = getApp()
      height = app.font.height
    # Set to Font Size Metrics
    result.minimum(height, height)
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
    ctx.color self.optionColor()
    # Fill Checkbox Background
    ctx.fill rect(
      rect.x, rect.y,
      rect.h, rect.h)
    # If Checked, Draw Mark
    if self.check[]:
      let
        size0 = rect.h shr 1
        size1 = size0 shr 1
      ctx.color(colors.text)
      ctx.fill rect(
        rect.x + size1, rect.y + size1,
        rect.h - size0, rect.h - size0)
    # Draw Text Next to Checkbox
    ctx.color(colors.text)
    ctx.text( # Centered Vertically
      rect.x + rect.h + 4, 
      rect.y - app.font.desc,
      self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = not self.check[]
