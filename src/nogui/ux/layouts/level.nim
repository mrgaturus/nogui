import base

# ---------------------
# GUI Layout Level Item
# ---------------------

widget UXLevelCell of UXLayoutCell:
  new tail(w: GUIWidget):
    result.cell0(w)

# ---------------------------
# GUI Layout Level Horizontal
# ---------------------------

widget UXLayoutHLevel:
  new level():
    discard

  method update =
    # TODO: allow customize margin
    let margin = getApp().font.size shr 1
    var w, h: int16
    # Calculate Min Size
    for widget in forward(self.first):
      let m = addr widget.metrics
      w += m.minW
      h = max(h, m.minH)
    # Store Min Size
    let m = addr self.metrics
    m.minW = w + margin
    m.minH = h

  method layout =
    var 
      left: int16
      metrics = addr self.metrics
      # Layout Dimensions
      right = metrics.w
      h = metrics.h
    # Arrange Children
    for widget in forward(self.first):
      let 
        m = addr widget.metrics
        w = m.minW
      if widget of UXLevelCell:
        right -= w
        m.x = right
      else: # Left
        m.x = left
        left += w
      # Set Minimun Size
      m.w = w
      m.h = h

# -------------------------
# GUI Layout Level Vertical
# -------------------------

widget UXLayoutVLevel:
  new vlevel():
    discard

  method update =
    # TODO: allow customize margin
    let margin = getApp().font.size shr 1
    var w, h: int16
    # Calculate Min Size
    for widget in forward(self.first):
      let m = addr widget.metrics
      w = max(w, m.minW)
      h += m.minH
    # Store Min Size
    let m = addr self.metrics
    m.minW = w
    m.minH = h + margin

  method layout =
    var 
      up: int16
      metrics = addr self.metrics
      # Layout Dimensions
      down = metrics.h
      w = metrics.w
    # Arrange Children
    for widget in forward(self.first):
      let 
        m = addr widget.metrics
        h = m.minH
      if widget of UXLevelCell:
        down -= h
        m.y = down
      else: # Left
        m.y = up
        up += h
      # Set Minimun Size
      m.w = w
      m.h = h
