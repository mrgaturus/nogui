import ./color/[base, hue, sv]

# ----------------
# Simple Color Bar
# ----------------

widget GUIColorCube:
  new colorcube(hsv: ptr HSVColor):
    result.add hue0bar(hsv)
    result.add sv0square(hsv)
    result.flags = wMouse

  new colorcube0triangle(hsv: ptr HSVColor):
    result.add hue0bar(hsv)
    result.add sv0triangle(hsv)
    result.flags = wMouse

  method layout =
    let 
      asc = getApp().font.asc shr 1
      bar = addr self.first.metrics
      square = addr self.last.metrics
      # Size metrics
      h = self.metrics.h
      w = self.metrics.w
      # Bar Offset
      o = w - bar.minW
    # Arrange Hue Bar
    bar.h = h
    bar.w = bar.minW
    bar.x = o
    # Arrange Hue Square
    square.h = h
    square.w = o - asc

# ------------------
# Color Wheel Square
# ------------------

widget GUIColorWheel:
  attributes:
    hold: GUIWidget

  new colorwheel(hsv: ptr HSVColor):
    let 
      wheel = hue0circle(hsv)
      square = sv0square(hsv)
    # Remove Widget Flags
    wheel.flags = wHidden
    square.flags = wHidden
    # Add Widgets
    result.add wheel
    result.add square
    result.flags = wMouse

  method draw(ctx: ptr CTXRender) =
    # Draw Two Widgets
    self.first.draw(ctx)
    self.last.draw(ctx)

  method layout =
    let
      wheel = addr self.first.metrics
      square = addr self.last.metrics
      # Calculate Center Point
      metrics = addr self.metrics
      w = metrics.w
      h = metrics.h
      cx = float32(w) * 0.5
      cy = float32(h) * 0.5
      # Calculate Radius
    const cos45div2 = 0.3535533905932738 * 0.7
    let radius = cos45div2 * float32 min(w, h)
    # Arrange Wheel as size
    wheel.w = w
    wheel.h = h
    # Locate Square Position
    square.x = int16(cx - radius)
    square.y = int16(cy - radius)
    square.w = int16(radius) shl 1
    square.h = int16(radius) shl 1

  method event(state: ptr GUIState) =
    const wPropagate = wVisible or wMouse
    # TODO: event propagation...
    if state.kind == evCursorClick:
      var hold: GUIWidget
      for widget in [self.first, self.last]:
        # TODO: event propagation pls...
        widget.flags = wPropagate
        if widget.pointOnArea(state.mx, state.my):
          hold = widget
        widget.flags = wHidden
      # Replace Hold
      self.hold = hold
    elif state.kind == evCursorRelease:
      self.hold = nil
    # TODO: event propagation pls x2...
    if not isNil(self.hold):
      let hold = self.hold
      # Execute Event
      hold.flags = self.flags
      hold.event(state)
      hold.flags = wHidden

# --------------------
# Color Wheel Triangle
# --------------------

widget GUIColorWheel0Triangle:
  attributes:
    hold: GUIWidget

  new colorwheel0triangle(hsv: ptr HSVColor):
    let 
      wheel = hue0circle(hsv)
      triangle = sv0triangle(hsv)
    # Remove Widget Flags
    wheel.flags = wHidden
    triangle.flags = wHidden
    # Add Widgets
    result.add wheel
    result.add triangle
    result.flags = wMouse

  method layout =
    let
      wheel = addr self.first.metrics
      triangle = addr self.last.metrics
      # Calculate Center Point
      metrics = addr self.metrics
      w = metrics.w
      h = metrics.h
      cx = float32(w) * 0.5
      cy = float32(h) * 0.5
    # Calculate Radius
    const cos45div2 = 0.3535533905932738
    let radius = cos45div2 * float32 min(w, h)
    # Arrange Wheel as size
    wheel.w = w
    wheel.h = h
    # Arrangle Triangle
    triangle.x = int16(cx - radius)
    triangle.y = int16(cy - radius)
    triangle.w = int16(radius) shl 1
    triangle.h = int16(radius) shl 1

  method draw(ctx: ptr CTXRender) = 
    self.first.draw(ctx)
    self.last.draw(ctx)

  proc collide(x, y: float32): bool =
    let 
      sv = cast[GUIColor0Triangle](self.last)
      # Calculate Center
      rect = rect (sv.rect)
      cx = (rect.x + rect.xw) * 0.5
      cy = (rect.y + rect.yh) * 0.5
      # Calculate Radius
      w = rect.xw - rect.x
      h = rect.yh - rect.y
      radius = min(w, h) * 0.5
      # Center Point
      xx = x - cx
      yy = y - cy
      # Check if is inside
      check0 = xx * xx + yy * yy < radius * radius
      p = sv.triangle().xymap(xx * 0.6 + cx, yy * 0.6 + cy)
      check1 = p.x >= 0.0 and p.y >= 0.0
      check2 = p.x <= 1.0 and p.y <= 1.0
    # Return Checks
    check0 and check1 and check2

  method event(state: ptr GUIState) =
    # TODO: event propagation...
    if state.kind == evCursorClick:
      var hold = self.first
      # Check Triangle
      if self.collide(state.px, state.py):
        hold = self.last
      # Replace Hold
      self.hold = hold
    elif state.kind == evCursorRelease:
      self.hold = nil
    # TODO: event propagation pls x2...
    if not isNil(self.hold):
      let hold = self.hold
      # Execute Event
      hold.flags = self.flags
      hold.event(state)
      hold.flags = wHidden
