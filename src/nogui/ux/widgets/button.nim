import ../[prelude, labeling]

type
  UXButtonStyle* = enum
    btnSimple
    btnClear
    btnActive

# ------------------
# Widget Button Base
# ------------------

widget UXButtonBase:
  attributes:
    label: string
    icon: CTXIconID
    lm: GUILabelMetrics
    # Button Color
    {.public.}:
      mode: UXButtonStyle

  proc style: CTXColor =
    case self.mode
    of btnSimple: self.itemColor()
    of btnClear: self.clearColor()
    of btnActive: self.activeColor()

  proc init0*(label: string, icon: CTXIconID) =
    self.flags = {wMouse}
    # Labeling Values
    self.icon = icon
    self.label = label

  proc draw0*(ctx: ptr CTXRender) =
    let
      app = getApp()
      rect = self.rect
      p = center(self.lm, rect)
    # Draw Button Background
    ctx.color self.style()
    ctx.fill rect(self.rect)
    # Draw icons And text
    ctx.color app.colors.text
    ctx.icon(self.icon, p.xi, p.yi)
    ctx.text(p.xt, p.yt, self.label)

  proc event0*(state: ptr GUIState): bool {.inline.} =
    state.kind == evCursorRelease and self.test(wHover)

  method update =
    let # Widget Metrics
      m = addr self.metrics
      # Calculate Label Metrics
      lm = metricsLabel(self.label, self.icon)
      extra = int16(lm.label > 0)
      # Application Padding
      pad0 = getApp().space.pad
      pad1 = pad0 shl extra
    # Change Min Size
    m.minW = lm.w + pad1
    m.minH = lm.h + pad0
    # Change Label Metrics
    self.lm = lm

# ----------------------
# Widget Button Callback
# ----------------------

widget UXButtonCB of UXButtonBase:
  attributes:
    cb: GUICallback

  new button(label: string, cb: GUICallback):
    result.init0(label, CTXIconEmpty)
    result.cb = cb

  new button(icon: CTXIconID, cb: GUICallback):
    result.init0("", icon)
    result.cb = cb

  new button(label: string, icon: CTXIconID, cb: GUICallback):
    result.init0(label, icon)
    result.cb = cb

  proc clear*: UXButtonCB =
    self.mode = btnClear; self

  method draw(ctx: ptr CTXRender) =
    self.draw0(ctx)

  method event(state: ptr GUIState) =
    if self.event0(state):
      send(self.cb)
