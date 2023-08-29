import base

# ----------------
# Grid Layout Band
# ----------------

type
  GridLane = object
    shrink: bool
    size, offset: int16
  GridLoc = object
    pos, size: int16
  # Horizontal and Vertical
  GridBand = object
    growCount: int16
    minSize, fitSize: int16
    # Lane Configurations
    cells: seq[GridLane]

proc band(count: int32): GridBand =
  # Initialize Band Metrics
  result.growCount = 0
  result.fitSize = 0
  result.minSize = 0
  # Allocate Band Size
  setLen(result.cells, count)

# ------------------------
# Grid Layout Lane Prepare
# ------------------------

proc clear(band: var GridBand) {.inline.} =
  # Reset Band Metrics
  band.growCount = 0
  band.minSize = 0
  band.fitSize = 0
  # Clear Cell Metrics
  for cell in mitems(band.cells):
    cell.size = 0
    cell.offset = 0

proc register(band: var GridBand, idx, span: int32, size: int16) =
  for i in 0 ..< span:
    # Replace Cell Min Size
    let cell = addr band.cells[idx + i]
    cell.size = max(cell.size, size)

proc prepare(band: var GridBand, margin: int16) =
  var min, fit, count: int16
  # Calculate Margin Size
  let
    l = int16 len(band.cells)
    pad = max(0, l - 1) * margin  
  # Calculate Fit Size
  for cell in items(band.cells):
    let size = cell.size
    min += size
    # Check if needs Fit
    if cell.shrink:
      fit += size
      inc(count)
  # Set Band Metrics
  band.minSize = min + pad
  band.fitSize = fit + pad
  band.growCount = l - count

# -------------------------
# Grid Layout Band Arranger
# -------------------------

proc arrange(band: var GridBand, size, margin: int16) =
  var cursor, grow: int16
  # Calculate Grow Size
  block:
    let count = band.growCount
    if count > 0: grow = (size - band.fitSize) div count
  # Sum Each Offset
  for cell in mitems(band.cells):
    cell.offset = cursor
    # Step Grow Size
    if not cell.shrink:
      cell.size = grow
      cursor += grow
    else: # Step Min Size
      cursor += cell.size
    # Step Margin
    cursor += margin

proc locate(band: var GridBand, idx, span: int32): GridLoc =
  let a = addr band.cells[idx]
  var size = a.size
  result.pos = a.offset
  # Calculate Size
  if span > 1:
    let i = min(idx + span - 1, high band.cells)
    # Calculate Acumulated Offset
    let b = addr band.cells[i]
    size = b.offset - a.offset + b.size
  # Set New Size
  result.size = size

# ----------------
# Grid Layout Cell
# ----------------

widget UXGridCell of UXLayoutCell:
  attributes:
    [x, y, w, h]: int16

  proc region(x, y, w, h: int16) =
    self.x = x
    self.y = y
    # Grid Span
    self.w = w
    self.h = h

  new cell(x, y: int16, widget: GUIWidget):
    result.region(x, y, 1, 1)
    result.cell0(widget)

  new cell(x, y, w, h: int16, widget: GUIWidget):
    result.region(x, y, w, h)
    result.cell0(widget)

# ------------------
# Grid Layout Widget
# ------------------

widget UXGridLayout:
  attributes:
    [w, h]: int32
    # Cell Configuration
    wBand: GridBand
    hBand: GridBand

  new grid(w, h: int32):
    result.w = w
    result.h = h
    # Allocate Cells
    result.wBand = band(w)
    result.hBand = band(h)

  proc activeMinX*(pos: int32, active = true) =
    self.wBand.cells[pos].shrink = active

  proc activeMinY*(pos: int32, active = true) =
    self.hBand.cells[pos].shrink = active

  method update =
    # Clear Bands
    clear(self.wBand)
    clear(self.hBand)
    # Register Widget Sizes
    for w in forward(self.first):
      if w of UXGridCell:
        let 
          c {.cursor.} = cast[UXGridCell](w)
          m = addr c.metrics
        register(self.wBand, c.x, c.w, m.minW)
        register(self.hBand, c.y, c.h, m.minH)
    # TODO: allow customize margin
    let margin = getApp().font.size shr 1
    # Prepare Grid Bands
    prepare(self.wBand, margin)
    prepare(self.hBand, margin)
    # Configure Min Size
    let m = addr self.metrics
    m.minW = self.wBand.minSize
    m.minH = self.hBand.minSize

  method layout =
    let
      m = addr self.metrics
      # TODO: allow customize margin
      margin = getApp().font.size shr 1
    # Arrange Cells with Current Size
    arrange(self.wBand, m.w, margin)
    arrange(self.hBand, m.h, margin)
    # Locate Each Widget
    for w in forward(self.first):
      if w of UXGridCell:
        let 
          c {.cursor.} = cast[UXGridCell](w)
          m = addr c.metrics
        # Widget Location
        var loc: GridLoc
        # Apply Horizontal
        loc = locate(self.wBand, c.x, c.w)
        m.x = loc.pos
        m.w = loc.size
        # Apply Vertical
        loc = locate(self.hBand, c.y, c.h)
        m.y = loc.pos
        m.h = loc.size

# TODO: export by default
export UXGridLayout
