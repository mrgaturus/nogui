# TODO: allow propagate event when grabbing
import ./color/[base, hue, sv]

# ----------------
# Simple Color Bar
# ----------------

widget UXColorCube:
  new colorcube(hsv: & HSVColor):
    result.add hue0bar(hsv)
    result.add sv0square(hsv)
    result.flags = {wMouse}

  new colorcube0triangle(hsv: & HSVColor):
    result.add hue0bar(hsv)
    result.add sv0triangle(hsv)
    result.flags = {wMouse}

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

widget UXColorWheel:
  new colorwheel(hsv: & HSVColor):
    let 
      wheel = hue0circle(hsv)
      square = sv0square(hsv)
    # Add Widgets
    result.add wheel
    result.add square
    result.flags = {wMouse}

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
    if self.test(wGrab): return
    # Find Collide Widget
    var found = self.first
    if pointOnArea(self.last, state.mx, state.my):
      found = self.last
    # Forward Event
    found.send(wsForward)

# --------------------
# Color Wheel Triangle
# --------------------

widget UXColorWheel0Triangle:
  new colorwheel0triangle(hsv: & HSVColor):
    let 
      wheel = hue0circle(hsv)
      triangle = sv0triangle(hsv)
    # Add Widgets
    result.add wheel
    result.add triangle
    result.flags = {wMouse}

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

  proc collide(x, y: float32): bool =
    let 
      sv = cast[UXColor0Triangle](self.last)
      # Calculate Center
      rect = rect (sv.rect)
      cx = (rect.x0 + rect.x1) * 0.5
      cy = (rect.y0 + rect.y1) * 0.5
      # Calculate Radius
      w = rect.x1 - rect.x0
      h = rect.y1 - rect.y0
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
    if self.test(wGrab): return
    # Find Collide Widget
    var found = self.first
    if self.collide(state.px, state.py):
      found = self.last
    # Propagate Event
    found.send(wsForward)
