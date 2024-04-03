import ../widgets/label
import base

# ----------------------
# Form Field Layout Cell
# ----------------------

widget UXLayoutField:
  attributes:
    size0: int16

  new field(name: string, w: GUIWidget):
    result.add label(name, hoLeft, veMiddle)
    result.add w

  new field(name, w: GUIWidget):
    result.add name
    result.add w

  new field(w: GUIWidget):
    result.add dummy()
    result.add w

  proc sizelabel: int16 {.inline.} =
    self.first.metrics.minW

  method update =
    let 
      metrics = addr self.metrics
      # Label Widget | Control Widget
      m0 = addr self.first.metrics
      m1 = addr self.last.metrics
      # Separator Horizontal
      sep = getApp().space.sepX
    # Calculate Min Size
    metrics.minW = m0.minW + sep + m1.minW
    metrics.minH = max(m0.minH, m1.minH)

  method layout =
    let
      m = addr self.metrics
      # Separator Horizontal
      size0 = self.size0
      sep = getApp().space.sepX
      # Label Widget | Control Widget
      m0 = addr self.first.metrics
      m1 = addr self.last.metrics
    # Arrange Label
    m0.x = 0
    m0.w = size0
    # Arrange Widget
    m1.x = size0 + sep
    m1.w = m.w - m1.x
    # Arrange Height
    m0.h = m.h
    m1.h = m.h

# -----------
# Form Layout
# -----------

widget UXLayoutForm:
  attributes:
    size0: int16

  new form():
    discard

  method update =
    var 
      w, h: int16
      size0, count: int16
    # Separator Vertical
    let sep = getApp().space.sepY
    # Iterate Childrens
    for widget in forward(self.first):
      let metrics = addr widget.metrics
      if widget of UXLayoutField:
        # Accumulate Labeling Size
        let s = cast[UXLayoutField](widget).sizelabel
        size0 = max(size0, s)
      # Accumulate Metrics
      w = max(w, metrics.minW)
      h += metrics.minH
      # Count Widget
      inc(count)
    # Form Metrics
    let 
      pad = max(0, count - 1) * sep
      m = addr self.metrics
    m.minW = w
    m.minH = h + pad
    # Labeling Max Size
    self.size0 = size0

  method layout = 
    let 
      size0 = self.size0
      w = self.metrics.w
      # Separator Vertical
      sep = getApp().space.sepY
    # Arrange Widgets
    var y: int16
    for widget in forward(self.first):
      # Arrange Field
      let 
        m = addr widget.metrics
        h = m.minH
      # Adjust Field Labeling
      if widget of UXLayoutField:
        cast[UXLayoutField](widget).size0 = size0
      # Arrange Widget Position
      m.x = 0; m.y = y
      m.w = w; m.h = h
      # Next Y Position
      y += h + sep
