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
    result.init0(cb)
    # Set Button Label
    result.label = label

  method update =
    let
      font = addr getApp().font
      m = addr self.metrics
      # Calculate Sizes
      w = width(self.label)
      h = font.height
      # TODO: allow customize margin
      pad = font.asc
    # Change Min Size
    m.minW = int16 w + pad
    m.minH = h + (pad shr 1)

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      colors = addr app.colors
      font = addr app.font
      # Font Metrics
      ox = self.metrics.minW - font.asc
      oy = font.height - font.baseline
    # Fill Button Background
    ctx.color self.itemColor()
    ctx.fill rect(self.rect)
    # Put Centered Text
    ctx.color(colors.text)
    ctx.text( # Draw Centered Text
      rect.x + (rect.w - ox) shr 1,
      rect.y + (rect.h - oy) shr 1, 
      self.label)

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
    # Button Opaque
    opaque: bool

  new button(icon: CTXIconID, cb: GUICallback):
    result.init0(cb)
    # Set Button Icon
    result.icon = icon
    result.label = ""

  new button(icon: CTXIconID, label: string, cb: GUICallback):
    result.init0(cb)
    # Set Button Icon Label
    result.icon = icon
    result.label = label

  proc opaque*: UXButton {.inline.} =
    self.opaque = true; self

  method update =
    let # Calculate Label Metrics
      m = addr self.metrics
      lm = metricsLabel(self.label, self.icon)
      # TODO: allow customize margin
      pad0 = getApp().font.asc shr 1
      pad1 = pad0 shl 1
    # Change Min Size
    m.minW = lm.w + pad1
    m.minH = lm.h + pad0
    # Change Label Metrics
    self.lm = lm

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      rect = self.rect
      p = center(self.lm, rect)
    # Decide Current Color
    let bgColor = if not self.opaque:
      self.itemColor()
    else: self.opaqueColor()
    # Draw Button Background
    ctx.color bgColor
    ctx.fill rect(self.rect)
    # Draw icons And text
    ctx.color app.colors.text
    ctx.icon(self.icon, p.xi, p.yi)
    ctx.text(p.xt, p.yt, self.label)

# -----------------
# GUI Opaque Button
# -----------------

widget UXButtonOpaque:
  attributes:
    icon: CTXIconID
    label: string
    # Label Metrics
    lm: GUILabelMetrics

  proc init0*(label: string, icon = CTXIconEmpty) =
    self.flags = wMouse
    # Labeling Values
    self.icon = icon
    self.label = label

  proc draw0*(ctx: ptr CTXRender, active: bool) =
    let
      app = getApp()
      rect = self.rect
      p = center(self.lm, rect)
      icon = self.icon
    # Decide Current Color
    let bgColor = if not active:
      self.opaqueColor()
    else: self.activeColor()
    # Fill Button Background
    ctx.color bgColor
    ctx.fill rect(self.rect)
    # Select Glyph Color
    ctx.color app.colors.text
    # Draw icons And text
    ctx.icon(icon, p.xi, p.yi)
    ctx.text(p.xt, p.yt, self.label)

  method update =
    let # Widget Metrics
      m = addr self.metrics
      icon = self.icon
      # TODO: allow customize margin
      pad0 = getApp().font.asc shr 1
      pad1 = pad0 shr 1
      # Calculate Label Metrics
      lm = metricsLabel(self.label, icon)
    # Change Min Size
    m.minW = lm.w + pad1
    m.minH = lm.h + pad0
    # Change Label Metrics
    self.lm = lm

# TODO: export by default
export UXButtonOpaque
