import ../[prelude, labeling]

widget UXButton:
  attributes:
    cb: GUICallback
    label: string

  proc init0(cb: GUICallback) =
    # Widget Standard Flag
    self.flags = wMouse
    self.cb = cb

  new button(label: string, cb: GUICallback):
    let metrics = addr getApp().font
    # Set to Font Size Metrics
    result.minimum(label.width + metrics.size,
      metrics.height - metrics.desc)
    # Init Callback
    result.init0(cb)
    result.label = label

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
  attributes:
    icon: CTXIconID
    lm: GUILabelMetrics

  new button(icon: CTXIconID, cb: GUICallback):
    result.init0(cb)
    result.icon = icon
    result.label = ""

  new button(icon: CTXIconID, label: string, cb: GUICallback):
    result.init0(cb)
    result.icon = icon
    result.label = label

  method update =
    let # Calculate Label Metrics
      m = addr self.metrics
      lm = metrics(self.icon, self.label)
      # TODO: allow customize margin
      pad = getApp().font.asc
    # Change Min Size
    m.minW = lm.w + pad
    m.minH = lm.h + (pad shr 1)
    # Change Label Metrics
    self.lm = lm

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      rect = self.rect
      p = center(self.lm, rect)
    # Draw Button Background
    ctx.color self.itemColor()
    ctx.fill rect(self.rect)
    # Draw icons And text
    ctx.color app.colors.text
    ctx.icon(self.icon, p.xi, p.yi)
    ctx.text(p.xt, p.yt, self.label)
