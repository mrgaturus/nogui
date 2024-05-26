from ../../prelude import GUIMetrics, getApp
from ../../../native/cursor import GUICursorSys

type
  DockSide* = enum
    dockTop
    dockDown
    dockLeft
    dockRight
    # No Sides
    dockNothing
  DockSides* = set[DockSide]
  # Dock Resize-Move Pivot
  DockPivot* = object
    sides*: DockSides
    # Pivot Capture
    metrics*: GUIMetrics
    x*, y*: int32

# -----------------
# Dock Panel Resize
# -----------------

proc resizePivot*(m: GUIMetrics, x, y: int32): DockPivot =
  let
    x0 = x - m.x
    y0 = y - m.y
    # Resize Borders
    pad = getApp().space.margin
    thr = pad + (pad shr 1)
  # Reside Pivot Sides
  var sides: DockSides
  # Check Horizontal Sides
  if x0 >= m.w - thr: sides.incl dockRight
  elif x0 < thr: sides.incl dockLeft
  # Check Vertical Sides
  if y0 >= m.h - thr: sides.incl dockDown
  elif y0 < thr: sides.incl dockTop
  # Create New Pivot
  DockPivot(
    x: x, y: y,
    # Pivot Capture
    metrics: m,
    sides: sides
  )

proc resizeCursor*(pivot: DockPivot): GUICursorSys =
  let sides = pivot.sides
  if sides == {}: cursorArrow
  # Check Horizontal
  elif sides < {dockLeft, dockRight}:
    cursorSizeHorizontal
  # Check Top Diagonals
  elif dockTop in sides:
    if dockLeft in sides: cursorSizeDiagLeft
    elif dockRight in sides: cursorSizeDiagRight
    else: cursorSizeVertical
  # Check Bottom Diagonals
  elif dockDown in sides:
    if dockLeft in sides: cursorSizeDiagRight
    elif dockRight in sides: cursorSizeDiagLeft
    else: cursorSizeVertical
  # No Resize Cursor
  else: cursorArrow

proc clamp(m: var GUIMetrics, m0: GUIMetrics) =
  let
    w = max(m0.minW, m.w)
    h = max(m0.minH, m.h)
  # Apply Position, Avoid Moving Side
  if m.x != m0.x: m.x = m.x - w + m.w
  if m.y != m0.y: m.y = m.y - h + m.h

proc resize*(pivot: DockPivot, x, y: int32): GUIMetrics =
  result = pivot.metrics
  # Calculate Resize Delta
  let 
    sides = pivot.sides
    dx = int16(x - pivot.x)
    dy = int16(y - pivot.y)
  # Down-Right Expanding
  if dockDown in sides: 
    result.h += dy
  if dockRight in sides: 
    result.w += dx
  # Top-Left Expanding
  if dockTop in sides:
    result.y += dy
    result.h -= dy
  if dockLeft in sides:
    result.x += dx
    result.w -= dx
  # Clamp Resized Metrics
  result.clamp(pivot.metrics)
