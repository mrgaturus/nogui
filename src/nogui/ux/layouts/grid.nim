import base

# ----------------
# Grid Layout Band
# ----------------

type
  GridLane = object
    shrink: bool
    size, offset: int16
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

# -----------------------
# Grid Layout Lane Config
# -----------------------

proc clear(band: var GridBand) {.inline.} =
  # Reset Band Metrics
  band.growCount = 0
  band.minSize = 0
  band.fitSize = 0
  # Clear Cell Metrics
  for cell in mitems(band.cells):
    cell.size = 0
    cell.offset = 0

proc record(band: var GridBand, idx, span: int32, size: int16) =
  for i in 0 ..< span:
    # Replace Cell Min Size
    let cell = addr band.cells[i]
    cell.size = max(cell.size, size)

# -----------------------
# Grid Layout Band Config
# -----------------------

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

proc offsets(band: var GridBand, size, margin: int16) =
  var cursor, grow: int16
  # Calculate Grow Size
  block:
    let count = band.growCount
    if count > 0:
      grow = (size - band.fitSize) div count
  # Sum Each Offset
  for cell in mitems(band.cells):
    cell.offset = cursor
    # Step Min Size or Grow
    if cell.shrink:
      cursor += cell.size
    else: cursor += grow
    # Step Margin
    cursor += margin

proc locate(band: var GridBand, idx: int32): int16 =
  discard

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

  method update =
    discard

  method layout =
    discard
