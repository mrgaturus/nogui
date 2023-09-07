import ../prelude

widget UXButton:
  attributes:
    cb: GUICallback
    label: string

  new button(label: string, cb: GUICallback):
    let metrics = addr getApp().font
    # Set to Font Size Metrics
    result.minimum(label.width + metrics.size,
      metrics.height - metrics.desc)
    # Widget Standard Flag
    result.flags = wMouse
    # Widget Attributes
    result.label = label
    result.cb = cb

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
      metrics = addr app.font
      # Text Center Offset
      offset = self.metrics.minW - metrics.size
    # Select Color State
    ctx.color self.itemColor()
    # Fill Button Background
    ctx.fill rect(self.rect)
    # Put Centered Text
    ctx.color(colors.text)
    ctx.text( # Draw Centered Text
      rect.x + (rect.w - offset) shr 1, 
      rect.y + metrics.asc shr 1, self.label)

  method event(state: ptr GUIState) =
    let cb = self.cb
    if state.kind == evCursorRelease and 
    self.test(wHover) and cb.valid: 
      cb.push()

# ---------------
# GUI Icon Button
# ---------------

widget UXIconButton of UXButton:
  discard
