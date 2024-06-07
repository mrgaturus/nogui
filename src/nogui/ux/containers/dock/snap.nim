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
    stick*: DockSide
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

proc clip*(m: var GUIMetrics, pivot: DockPivot) =
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

proc orient*(m: GUIMetrics, pivot: DockPivot): DockSide =
  let clip = pivot.clip
  if isNil(clip) or m.w == 0:
    return dockNothing
  let
    x0 = m.x
    x1 = x0 + m.w
    # Calculate Distances
    dx0 = x0 - clip.x
    dx1 = clip.x + clip.w - x1
  # Check Stick to Side
  case pivot.stick
  of dockLeft: dockRight
  of dockRight: dockLeft
  # Check Which is Near to a Side
  elif dx1 < dx0: dockLeft
  else: dockRight

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
  # Check Horizontal Sides
  if x0 > m.w - thr1: sides.incl dockRight
  elif x0 < thr1: sides.incl dockLeft
  # Check Vertical Sides
  if y0 > m.h - thr1: sides.incl dockDown
  elif y0 < thr1: sides.incl dockTop
  # Pivot Point
  pivot.x = x
  pivot.y = y
  # Pivot Resize Capture
  pivot.metrics = m
  pivot.sides = sides

proc restrict0*(pivot: var DockPivot) =
  let
    stick = pivot.stick
    sides = pivot.sides
    # Restrict Sticky Sides
    check0 = stick == dockLeft and sides * {dockLeft, dockTop} != {}
    check1 = stick == dockRight and sides * {dockRight, dockTop} != {}
  if check0 or check1:
    pivot.sides = {dockLocked}

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

# --------------------
# Widget Dock Grouping
# --------------------

proc groupSide*(r: GUIRect, x, y: int32): DockSide =
  # Move Point As Relative
  let
    x0 = x - r.x
    y0 = y - r.y
    thr = getApp().font.height shl 1
  # Check Inside Rectangle
  if x0 >= 0 and y0 >= 0 and x0 < r.w and y0 < r.h:
    # Check Vertical Sides
    if y0 >= 0 and y0 <= thr: dockTop
    elif y0 >= r.h - thr and y0 < r.h: dockDown
    # Check Horizontal Sides
    elif x0 >= 0 and x0 <= thr: dockLeft
    elif x0 >= r.w - thr and x0 < r.w: dockRight
    # Otherwise Nothing
    else: dockNothing
  else: dockNothing

proc groupHint*(r: GUIRect, side: DockSide): GUIRect =
  let thr = getApp().font.height
  # Calculate Hint Rect
  result = r
  case side
  of dockLeft:
    result.w = thr
  of dockRight:
    result.x += r.w - thr
    result.w = thr
  of dockTop:
    result.h = thr
  of dockDown:
    result.y += result.h - thr
    result.h = thr
  else: discard

# --------------------
# Widget Dock Snapping
# --------------------

proc checkTop(a, b: GUIMetrics, thr: int32): bool =
  if abs(a.y - b.y - b.h) < thr:
    let
      ax0 = a.x
      ax1 = a.x + a.w
      # Sticky Area
      x0 = b.x
      x1 = x0 + b.w
      # X Distance Check A
      check0a = ax0 >= x0 and ax0 <= x1
      check1a = ax1 >= x0 and ax1 <= x1
      # X Distance Check B
      check0b = x0 >= ax0 and x0 <= ax1
      check1b = x1 >= ax0 and x1 <= ax1
      # Merge Distance Checks
      check0 = check0a or check0b
      check1 = check1a or check1b
    # Check if is sticky to top side
    result = check0 or check1

proc checkLeft(a, b: GUIMetrics, thr: int32): bool =
  if abs(a.x - b.x - b.w) < thr:
    let
      ay0 = a.y
      ay1 = a.y + a.h
      # Sticky Area
      y0 = b.y
      y1 = y0 + b.h
      # X Distance Check
      check0a = ay0 >= y0 and ay0 <= y1
      check1a = ay1 >= y0 and ay1 <= y1
      # X Distance Check B
      check0b = y0 >= ay0 and y0 <= ay1
      check1b = y1 >= ay0 and y1 <= ay1
      # Merge Distance Checks
      check0 = check0a or check0b
      check1 = check1a or check1b
    # Check if is sticky to top side
    result = check0 or check1

proc cornerX(a, b: GUIMetrics, thr: int32): int16 =
  let 
    d0 = a.x - b.x
    d1 = d0 + a.w - b.w
  # Check Nearly Deltas
  if abs(d0) < thr: b.x
  elif abs(d1) < thr:
    b.x + b.w - a.w
  else: a.x

proc cornerY(a, b: GUIMetrics, thr: int32): int16 =
  let 
    d0 = a.y - b.y
    d1 = d0 + a.h - b.h
  # Check Nearly Deltas
  if abs(d0) < thr: b.y
  elif abs(d1) < thr:
    b.y + b.h - a.h
  else: a.y

proc snap*(a, b: GUIWidget): tuple[x, y: int16] =
  let
    a0 = a.metrics
    b0 = b.metrics
    # TODO: allow custom margin
    app = getApp()
    thr = app.space.pad
    pad = app.space.margin shr 1
  # Calculate Where is
  let side = 
    if checkTop(a0, b0, thr): dockTop
    elif checkLeft(a0, b0, thr): dockLeft
    # Check Opposite Dock Sides
    elif checkTop(b0, a0, thr): dockDown
    elif checkLeft(b0, a0, thr): dockRight
    # No Sticky Found
    else: dockNothing
  # Initial Position
  var
    x = a0.x
    y = a0.y
  # Calculate Sticky Position
  case side
  of dockTop: 
    y = b0.y + b0.h - pad
    x = cornerX(a0, b0, thr)
  of dockDown: 
    y = b0.y - a0.h + pad
    x = cornerX(a0, b0, thr)
  of dockLeft: 
    x = b0.x + b0.w - pad
    y = cornerY(a0, b0, thr)
  of dockRight: 
    x = b0.x - a0.w + pad
    y = cornerY(a0, b0, thr)
  # No Snapping Found
  else: discard
  # Return Sticky Info
  result.x = x
  result.y = y
