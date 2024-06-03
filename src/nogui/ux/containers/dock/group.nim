import ../../[prelude, pivot]
import ../../../core/tree
# Import Dock Snap
import snap

proc away(state: ptr GUIState, pivot: ptr GUIStatePivot): bool =
  pivot[].capture(state)
  # Check if Dragging is Outside Enough
  let away0 = float32 getApp().font.asc shr 1
  result = pivot.away >= away0

# -------------------------
# Dock Group Row -> Columns
# -------------------------

widget UXDockRow:
  new dockrow():
    result.kind = wkLayout

  method update =
    var
      w, h0, h1: int16
      count: int16
    # Calculate Row Minimun Size
    for dock in forward(self.first):
      let m = addr dock.metrics
      # Accumulate Metrics
      h0 += m.h
      h1 += m.minH
      w = max(w, m.minW)
      # Count Panels
      inc(count)
    # Calculate Row Dimensions
    let
      m = addr self.metrics
      # Row Border Offset Count
      pad0 = getApp().space.margin shr 1
      pad = pad0 * max(count - 1, 0)
    # Replace Row Height
    m.h = h0 - pad
    m.minH = h1 - pad
    # Replace Row Width
    m.w = max(m.w, w)
    m.minW = w

  method layout =
    let
      pad = getApp().space.margin shr 1
      m0 = addr self.metrics
    # Row Positioning
    let w = max(m0.w, m0.minW)
    var y: int16
    # Locate Row Panels
    for dock in forward(self.first):
      let m = addr dock.metrics
      m.x = 0; m.y = y; m.w = w
      # Next Row Position
      y += m.h - pad

widget UXDockColumns:
  new dockcolumns():
    result.kind = wkLayout

  method update =
    var
      w0, w1, h0, h1: int16
      count: int16
    # Calculate Columns Minimun Size
    for row in forward(self.first):
      let m = addr row.metrics
      # Accumulate Metrics
      w0 += m.w
      w1 += m.minW
      h0 = max(h0, m.h)
      h1 = max(h1, m.minH)
      # Count Rows
      inc(count)
    # Columns Dimensions
    let
      m = addr self.metrics
      # Group Border Offset Count
      pad0 = getApp().space.margin shr 1
      pad = pad0 * max(count - 1, 0)
    # Replace Columns Dimensions
    m.minW = w1 - pad
    m.w = w0 - pad
    m.minH = h1
    m.h = h0

  method layout =
    let pad = getApp().space.margin shr 1
    # Locate Group Rows
    var x: int16
    for dock in forward(self.first):
      let m = addr dock.metrics
      m.y = 0; m.x = x
      # Next Row Position
      x += m.w - pad

# ---------------------
# Dock Group Bar Widget
# ---------------------

widget UXDockGroupBar:
  attributes:
    pivot: GUIStatePivot
    m0: GUIMetrics

  new dockgroup0bar():
    result.flags = {wMouse}

  method update =
    let m = addr self.metrics
    m.minH = getApp().font.height

  method event(state: ptr GUIState) =
    let
      pivot = addr self.pivot
      away = state.away(pivot)
      locked = pivot.locked
    # Capture Parent Metrics
    if away and locked:
      self.m0 = self.parent.metrics
      getWindow().cursor(cursorMove)
      # Start Moving Parent
      pivot.locked = false
    # Move Parent Metrics
    elif away and not locked:
      let
        m0 = addr self.m0
        m = addr self.parent.metrics
      m.x = m0.x + int16(state.mx - pivot.mx)
      m.y = m0.y + int16(state.my - pivot.my)
      # Relayout Parent Metrics
      relax(self.parent, wsLayout)

  method handle(reason: GUIHandle) =
    if reason == outGrab:
      getWindow().cursorReset()

  method draw(ctx: ptr CTXRender) =
    let color = getApp().colors.item
    # Draw Group Bar Rectangle
    ctx.color(color and 0xF0FFFFFF'u32)
    ctx.fill rect(self.rect)

# ------------------------
# Dock Group Resize Widget
# ------------------------

widget UXDockGroupResize:
  attributes:
    pivot: DockPivot
    # Resize Targets
    {.cursor.}:
      group: GUIWidget
      row: GUIWidget
      target: GUIWidget

  new dockgroup0resize():
    result.flags = {wMouse, wVisible}

  proc inside(panel: GUIWidget, x, y: int32): bool =
    var
      target {.cursor.} = panel
      pivot = resizePivot(panel, x, y)
      sides = pivot.sides
    # Skip if not Side Selected
    if sides == {}:
      return false
    # Manipulate Top Panel if Top Found
    let top {.cursor.} = panel.prev
    if dockTop in sides and not isNil(top):
      sides = sides - {dockTop} + {dockDown}
      target = top
    # Check if is at Resize Side
    pivot.sides = sides
    result = sides != {}
    if result:
      self.target = target
      self.row = target.parent
      self.pivot = pivot
      self.rect = panel.rect

  proc resize(x, y: int32) =
    let
      pivot = addr self.pivot
      delta = pivot[].resize(x, y)
      # Dock Resize Targets
      m0 = addr self.group.metrics
      m1 = addr self.row.metrics
      m2 = addr self.target.metrics
    # Apply Delta to Targets
    m0.x = delta.x
    m0.y = delta.y
    m1.w = delta.w
    m2.h = delta.h
    # Relayout Widget Group
    self.group.relax(wsLayout)

  method event(state: ptr GUIState) =
    if {wHover, wGrab} * self.flags == {wHover}:
      getWindow().cursor(resizeCursor self.pivot)
      # Store Cursor Pivot
      self.pivot.x = state.mx
      self.pivot.y = state.my
    elif self.test(wGrab):
      self.resize(state.mx, state.my)

  method handle(reason: GUIHandle) =
    if reason == inGrab:
      let
        m0 = addr self.group.metrics
        m1 = addr self.row.metrics
        m2 = addr self.target.metrics
        m = addr self.pivot.metrics
      # Store Metrics Pivot
      m.x = m0.x
      m.y = m0.y
      m.w = m1.w
      m.h = m2.h
      # Store Min Width
      m.minW = m1.minW
    elif {wHover, wGrab} * self.flags == {}:
      getWindow().cursorReset()

# -----------------
# Dock Group Widget
# -----------------

widget UXDockGroup:
  attributes:
    resize: UXDockGroupResize
    # Dock Group Widgets
    {.cursor.}:
      columns: UXDockColumns
      bar: UXDockGroupBar

  new dockgroup(columns: UXDockColumns):
    let
      bar = dockgroup0bar()
      resize = dockgroup0resize()
    # Configure Dock Group
    result.kind = wkLayout
    result.columns = columns
    result.bar = bar
    # Configure Dock Resize
    resize.group = result
    result.resize = resize
    # Add Dock Group Widgets
    result.add(columns)
    result.add(bar)

  method update =
    let
      pad = getApp().space.margin shr 1
      m0 = addr self.columns.metrics
      m1 = addr self.bar.metrics
      # Dock Group Metrics
      m = addr self.metrics
      h = m1.minH + pad
    # Calculate Dimensions
    m.w = m0.w
    m.h = m0.h + h
    m.minW = m0.minW
    m.minH = m0.minH + h
    # Clamp Dimensions
    m.w = max(m.w, m.minW)
    m.h = max(m.h, m.minH)

  method layout =
    let
      pad = getApp().space.margin shr 1
      m0 = addr self.columns.metrics
      m1 = addr self.bar.metrics
      m = addr self.metrics
    # Locate Group Bar
    m1.x = pad; m1.w = m.w - pad - pad
    m1.y = pad; m1.h = m1.minH
    # Locate Group Columns
    m0.x = 0
    m0.y = m1.y + m1.h

  method draw(ctx: ptr CTXRender) =
    ctx.color rgba(255, 255, 0, 255)
    ctx.fill rect(self.rect)

  # -- Dock Group Finder --
  proc inside*(x, y: int32): GUIWidget =
    let
      bar {.cursor.} = self.bar
      columns {.cursor.} = self.columns
      resize {.cursor.} = self.resize
    # Check Inside Bar
    if bar.pointOnArea(x, y):
      return bar
    # Check Inside Columns
    result = columns.inside(x, y)
    if result == columns:
      return self
    # Check Inside Resize
    if resize.inside(result, x, y):
      result = resize
