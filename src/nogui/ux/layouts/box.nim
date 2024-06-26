# TODO: create metrics for padding and margin
import base
export min

# ---------------
# Vertical Layout
# ---------------

widget UXLayoutVBox:
  attributes:
    [fit, count]: int16

  new vertical():
    result.kind = wkLayout

  method update =
    var 
      w, h, count: int16
      fit, grow: int16
    # Iterate Childrens
    for widget in forward(self.first):
      let metrics = addr widget.metrics
      # Accumulative Width
      h += metrics.minH
      w = max(w, metrics.minW)
      # Check if is Fit
      if widget of UXMinCell:
        fit += metrics.minH
      else: inc(grow)
      # Count Widget
      inc(count)
    # Calculate Margin Padding
    let 
      sep = getApp().space.sepY
      pad = max(0, count - 1) * sep
      metrics = addr self.metrics
    # Adjust width with margin
    metrics.minW = w
    metrics.minH = h + pad
    # Store Box Attributes
    self.fit = fit + pad
    self.count = grow

  method layout =
    let 
      h = self.metrics.h
      w = self.metrics.w
      # Growable Widgets Size
      sep = getApp().space.sepY
      count = self.count
      # Last Widget Adjust
      last {.cursor.} = self.last
    # Calculate Grow Size
    var grow: int16
    if count > 0: 
      grow = (h - self.fit) div count
    # Arrange Widgets
    var y: int16
    for widget in forward(self.first):
      let metrics = addr widget.metrics
      # Calculate Height
      let size =
        if widget of UXMinCell:
          metrics.minH
        elif widget != last: grow
        else: h - y
      # Set Metrics
      metrics.x = 0
      metrics.y = y
      metrics.w = w
      metrics.h = size
      # Next Widget
      y += size + sep

# -----------------
# Horizontal Layout
# -----------------

widget UXLayoutHBox:
  attributes:
    [fit, count]: int16

  new horizontal():
    result.kind = wkLayout

  method update =
    var 
      w, h, count: int16
      fit, grow: int16
    # Iterate Childrens
    for widget in forward(self.first):
      let metrics = addr widget.metrics
      # Accumulative Width
      w += metrics.minW
      h = max(h, metrics.minH)
      # Check if is Fit
      if widget of UXMinCell:
        fit += metrics.minW
      else: inc(grow)
      # Count Widget
      inc(count)
    # Calculate Margin Padding
    let 
      sep = getApp().space.sepX
      pad = max(0, count - 1) * sep
      metrics = addr self.metrics
    # Adjust width with margin
    metrics.minW = w + pad
    metrics.minH = h
    # Store Box Attributes
    self.fit = fit + pad
    self.count = grow

  method layout =
    let 
      h = self.metrics.h
      w = self.metrics.w
      # Growable Widgets Size
      sep = getApp().space.sepX
      count = self.count
      # Last Widget Adjust
      last {.cursor.} = self.last
    # Calculate Grow Size
    var grow: int16
    if count > 0: 
      grow = (w - self.fit) div count
    # Arrange Widgets
    var x: int16
    for widget in forward(self.first):
      let metrics = addr widget.metrics
      # Calculate Width
      let size =
        if widget of UXMinCell:
          metrics.minW
        elif widget != last: grow
        else: w - x
      # Set Metrics
      metrics.x = x
      metrics.y = 0
      metrics.w = size
      metrics.h = h
      # Next Widget
      x += size + sep
