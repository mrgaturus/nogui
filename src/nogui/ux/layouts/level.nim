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
    result.kind = wkLayout

  method update =
    # Separator Horizontal
    let sep = getApp().space.sepX
    var w, h, count: int16
    # Calculate Min Size
    for widget in forward(self.first):
      let m = addr widget.metrics
      w += m.minW
      h = max(h, m.minH)
      # Check if there is a Tail Cell
      count += cast[int16](widget of UXLevelCell)
    # Store Min Size
    let m = addr self.metrics
    m.minW = w
    m.minH = h
    # Check Margin
    if count > 0:
      m.minW += sep

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
    result.kind = wkLayout

  method update =
    # Separator Vertical
    let sep = getApp().space.sepY
    var w, h, count: int16
    # Calculate Min Size
    for widget in forward(self.first):
      let m = addr widget.metrics
      w = max(w, m.minW)
      h += m.minH
      # Check if there is a Tail Cell
      count += cast[int16](widget of UXLevelCell)
    # Store Min Size
    let m = addr self.metrics
    m.minW = w
    m.minH = h
    # Check Margin
    if count > 0:
      m.minH += sep

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
