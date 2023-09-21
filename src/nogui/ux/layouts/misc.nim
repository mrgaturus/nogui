import base

# ---------------
# GUI Adjust Cell
# ---------------

type
  UXPosHKind* = enum
    hoLeft
    hoMiddle
    hoRight
  UXPosVKind* = enum
    veTop
    veMiddle
    veRight

proc calc(force, min, size: int16, scale: float32): int16 =
  result = # Select Which Size
    if force == 0: size
    elif force < 0: min
    else: force
  # Scale Selected Dimension
  result = int16(scale * float32 result)

proc offset(m: int16): int16 =
  # TODO: allow customize global margin
  # TODO: scale customized margin
  if m >= 0: m
  else: getApp().font.size shr 1

# ----------------------
# GUI Adjust Cell Layout
# ----------------------

widget UXAdjustLayout:
  attributes: {.public.}:
    # Aligment Position
    hoAlign: UXPosHKind
    veAlign: UXPosVKind
    # Overwrite/Proportion
    [forceW, forceH]: int16
    [scaleW, scaleH]: float32

  proc init(w: GUIWidget) =
    self.scaleW = 1.0
    self.scaleH = 1.0
    # Store Widget
    self.add w

  new adjust(w: GUIWidget):
    result.init(w)

  new packed(w: GUIWidget):
    result.init(w)
    # Negative Overwrite
    result.forceW = low int16
    result.forceH = low int16

  proc hoMetric(m: ptr GUIMetrics) =
    let w = self.metrics.w
    m.x = # Adjust X Aligment
      case self.hoAlign
      of hoLeft: 0
      of hoMiddle:
        (w - m.w) shr 1
      of hoRight:
        w - m.w

  proc veMetric(m: ptr GUIMetrics) =
    let h = self.metrics.h
    m.y = # Adjust Y Aligment
      case self.veAlign
      of veTop: 0
      of veMiddle:
        (h - m.h) shr 1
      of veRight:
        h - m.h

  method update =
    let 
      m0 = addr self.metrics
      m = addr self.first.metrics
    # Ensure is one widget
    assert self.first == self.last
    # Mimic Min Size
    m0.minW = m.minW
    m0.minH = m.minH

  method layout =
    let
      # Encapsulated Widget
      m0 = addr self.metrics
      m = addr self.first.metrics
    # Calculate Sizes
    m.w = calc(self.forceW, m.minW, m0.w, self.scaleW)
    m.h = calc(self.forceH, m.minH, m0.h, self.scaleH)
    # Adjust Widget Metrics
    hoMetric(self, m)
    veMetric(self, m)

# -----------------
# GUI Margin Layout
# -----------------

widget UXMarginLayout:
  attributes: {.public.}:
    [marginW, marginH]: int16

  new margin(w: GUIWidget):
    result.add w
    # Use Default Margin
    result.marginW = low int16
    result.marginH = low int16

  new margin(size: int16, w: GUIWidget):
    result.add w
    # Customized Margin
    result.marginW = size
    result.marginH = size

  method update =
    let 
      m0 = addr self.metrics
      m = addr self.first.metrics
      # Padding Sizes
      pw = offset(self.marginW) shl 1
      ph = offset(self.marginH) shl 1
    # Ensure is one widget
    assert self.first == self.last
    # Mimic Min Size + Margin
    m0.minW = m.minW + pw
    m0.minH = m.minH + ph

  method layout =
    let 
      m0 = addr self.metrics
      m = addr self.first.metrics
      # Margin Metric
      ow = offset(self.marginW)
      oh = offset(self.marginH)
      # Marging Padding
      pw = ow shl 1
      ph = oh shl 1
    # Apply Offset
    m.x = ow
    m.y = oh
    # Apply Padding
    m.w = m0.w - pw
    m.h = m0.h - ph
