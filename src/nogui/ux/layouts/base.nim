import ../prelude
export prelude

# ------------------------
# Widget Layout Cell Hints
# ------------------------

widget UXLayoutCell:
  proc cell0*(w: GUIWidget) =
    # Cleared Cell
    assert self.first == nil
    assert self.last == nil
    # Add Widget to Cell
    self.kind = wkLayout
    self.add w

  method update =
    # Ensure is one widget
    assert self.first == self.last
    # Mimic Capsulated Widget
    let first {.cursor.} = self.first
    self.metrics = first.metrics

  method layout =
    # Ensure is one widget
    assert self.first == self.last
    # Forward Capsulated Widget
    let 
      first {.cursor.} = self.first
      metrics = addr first.metrics
    # Adjust Relative
    metrics[] = self.metrics
    metrics.x = 0
    metrics.y = 0

# -----------------
# Widget Layout Fit
# -----------------

widget UXDummy:
  new dummy():
    discard

widget UXMinCell of UXLayoutCell:
  new min(w: GUIWidget):
    result.cell0(w)
