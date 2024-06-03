import ../../[prelude, pivot]

proc away(state: ptr GUIState, pivot: ptr GUIStatePivot): bool =
  pivot[].capture(state)
  # Check if Dragging is Outside Enough
  let away0 = float32 getApp().font.asc shr 1
  result = pivot.away >= away0

# ----------------
# Dock Group Split
# ----------------

widget UXDockVertical:
  new dockvertical():
    discard

  method update =
    discard

  method event(state: ptr GUIState) =
    discard

  method draw(ctx: ptr CTXRender) =
    discard


widget UXDockHorizontal:
  new dockhorizontal():
    discard

  method update =
    discard

  method event(state: ptr GUIState) =
    discard

  method draw(ctx: ptr CTXRender) =
    discard

# --------------
# Dock Group Row
# --------------

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
    # Replace Row Dimensions
    m.minH = h1 - pad
    m.h = h0 - pad
    m.minW = w
    m.w = w

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

  #method draw(ctx: ptr CTXRender) =
  #  ctx.color rgba(255, 255, 0, 255)
  #  #ctx.color getApp().colors.item
  #  ctx.fill rect(self.rect)

# ---------------------
# Dock Group Bar Widget
# ---------------------

widget UXDockGroupBar:
  attributes:
    pivot: GUIStatePivot
    m0: GUIMetrics

  new dockgroupbar():
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
      send(self.parent, wsLayout)

  method handle(reason: GUIHandle) =
    if reason == outGrab:
      getWindow().cursorReset()

  method draw(ctx: ptr CTXRender) =
    let color = getApp().colors.item
    # Draw Group Bar Rectangle
    ctx.color(color and 0xF0FFFFFF'u32)
    ctx.fill rect(self.rect)

# -----------------
# Dock Group Widget
# -----------------

widget UXDockGroup:
  attributes:
    {.cursor.}:
      bar: UXDockGroupBar

  new dockgroup():
    result.flags = {wMouse}
    # Add Group Drag Bar
    let bar = dockgroupbar()
    result.bar = bar
    result.add(bar)

  method update =
    var
      w0, w1, h: int16
      count: int16
    # Calculate Group Minimun Size
    for row in forward(self.bar.next):
      let m = addr row.metrics
      # Accumulate Metrics
      w0 += m.w
      w1 += m.minW
      h = max(h, m.minH)
      # Count Rows
      inc(count)
    # Group Dimensions
    let
      m = addr self.metrics
      # Group Border Offset Count
      pad0 = getApp().space.margin shr 1
      pad = pad0 * max(count - 1, 0)
    # Append Group Bar Height
    h += self.bar.metrics.minH + pad0
    # Replace Group Dimensions
    m.minW = w1 - pad
    m.w = w0 - pad
    m.minH = h
    m.h = h

  method layout =
    let
      pad = getApp().space.margin shr 1
      m0 = addr self.metrics
      m1 = addr self.bar.metrics
    # Locate Group Bar
    m1.x = pad; m1.w = m0.w - pad - pad
    m1.y = pad; m1.h = m1.minH
    # Locate Group Rows
    var x: int16
    let y = m1.y + m1.h
    for dock in forward(self.bar.next):
      let m = addr dock.metrics
      m.y = y; m.x = x
      # Next Row Position
      x += m.w - pad

  method event(state: ptr GUIState) =
    discard

  #method draw(ctx: ptr CTXRender) =
  #  ctx.color rgba(255, 255, 0, 255)
  #  ctx.fill rect(self.rect)
