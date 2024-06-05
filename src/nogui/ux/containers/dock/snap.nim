from ../../prelude import
  GUIWidget, GUIMetrics, GUIRect, getApp
from ../../../native/cursor import GUICursorSys

type
  DockSide* = enum
    dockTop
    dockDown
    dockLeft
    dockRight
    # Dock Extra
    dockMove
    dockLocked
    dockNothing
  DockSides* = set[DockSide]
  # Dock Resize-Move Pivot
  DockPivot* = object
    clip*: ptr GUIMetrics
    metrics*: GUIMetrics
    # Pivot Capture
    sides*: DockSides
    x*, y*: int32

# -----------------
# Dock Panel Cursor
# -----------------

proc cursor*(pivot: DockPivot): GUICursorSys =
  let sides = pivot.sides
  if sides == {}: cursorArrow
  elif sides == {dockMove}: cursorMove
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

# ----------------------------
# Dock Panel Clipping/Clamping
# ----------------------------

proc clamp(m: var GUIMetrics, pivot: DockPivot) =
  let
    m0 = addr pivot.metrics
    w = max(m0.minW, m.w)
    h = max(m0.minH, m.h)
  # Apply Position, Avoid Moving Side
  if m.x != m0.x: m.x = m.x - w + m.w
  if m.y != m0.y: m.y = m.y - h + m.h
  # Replace Dimensions
  m.w = w
  m.h = h

proc clip(m: var GUIMetrics, pivot: DockPivot) =
  if isNil(pivot.clip):
    return
  let
    c0 = pivot.clip
    m0 = addr pivot.metrics
    thr = getApp().font.height shl 1
  # Clip Vertical
  if m.y < 0:
    if m.h > m0.h:
      m.h += m.y
    m.y = 0
  elif m.y > c0.h - thr:
    m.y = c0.h - thr
  # Clip Horizontal
  if m.x + m.w < thr:
    m.x = thr - m.w
  elif m.x > c0.w - thr:
    m.x = c0.w - thr

# -----------------
# Dock Panel Moving
# -----------------

proc move0*(pivot: var DockPivot, panel: GUIWidget, x, y: int32) =
  pivot.x = x
  pivot.y = y
  # Pivot Move Capture
  pivot.metrics = panel.metrics
  pivot.sides = {dockMove}

proc move*(pivot: DockPivot, x, y: int32): GUIMetrics =
  result = pivot.metrics
  result.x += int16(x - pivot.x)
  result.y += int16(y - pivot.y)
  # Clip Moved Metrics
  result.clip(pivot)

# -------------------
# Dock Panel Resizing
# -------------------

proc resize0*(pivot: var DockPivot, panel: GUIWidget, x, y: int32) =
  let
    app = getApp()
    m = panel.metrics
    # Relative Position
    x0 = x - panel.rect.x
    y0 = y - panel.rect.y
    # Resize Borders
    pad = app.space.margin
    thr0 = pad + (pad shr 1)
    thr1 = app.font.asc
    # Check Small Sides
    check0 = x0 >= thr0 and x0 <= m.w - thr0
    check1 = y0 >= thr0 and y0 <= m.h - thr0
  # Check Pivot Small Sides
  var sides: DockSides
  if check0 and check1:
    pivot.sides = sides   
    return
  # Reside Pivot Sides
  # Check Horizontal Sides
  if x0 > m.w - thr1: sides.incl dockRight
  elif x0 < thr1: sides.incl dockLeft
  # Check Vertical Sides
  if y0 > m.h - thr1: sides.incl dockDown
  elif y0 < thr1: sides.incl dockTop
  # Pivot Cursor
  pivot.x = x
  pivot.y = y
  # Pivot Resize Capture
  pivot.metrics = m
  pivot.sides = sides

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
  result.clamp(pivot)
  result.clip(pivot)
