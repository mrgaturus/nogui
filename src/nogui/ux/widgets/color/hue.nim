from math import 
  sin, cos, arctan2, log2, PI
import base

# ----------------------
# Color Hue Vertical Bar
# ----------------------

widget GUIHue0Bar of GUIColor0Base:
  new hue0bar(hsv: ptr HSVColor, slave = false):
    result.hsv = hsv
    result.slave = slave
    result.flags = wMouse
    # Minimun Width Size
    let w = getApp().font.height
    result.metrics.minW = w + w shr 2

  proc drawHue(ctx: ptr CTXRender) =
    ctx.addVerts(14, 36)
    let h = self.rect.h / 6
    var # Iterator
      i, j, k: int32
      hue: uint32
      rect = rect self.rect
    # Locate Initial Position
    rect.yh = rect.y
    while i < 7:
      if i < 6: # Quad Elements
        ctx.triangle(k, j, j + 1, j + 2)
        ctx.triangle(k + 3, j + 1, j + 2, j + 3)
        # Hue Color
        hue = hueSix[i]
      else: hue = hueSix[0]
      # Bar Vertexs Segment
      ctx.vertexCOL(j, rect.x, rect.yh, hue)
      ctx.vertexCOL(j + 1, rect.xw, rect.yh, hue)
      rect.yh += h # Next Y
      # Next Hue Quad
      i += 1; j += 2; k += 6

  proc drawCursor(ctx: ptr CTXRender) =
    # Calculate Cursor Color
    let
      h = self.hsv.h
      item = toRGB self.itemColor()
      # Contrast Colors
      color0 = HSVColor(h: h, s: 1.0, v: 1.0).toRGB
      color1 = contrast(item, color0)
      # Metric Offset With Min Size
      offset = float32(self.metrics.minW) * 0.25
    # Locate Rectangle
    var 
      rect = rect(self.rect)
      calc = rect.y + (rect.yh - rect.y) * h
    # Calculate Metrics
    rect.y = calc - offset
    rect.yh = calc + offset
    # Fill Current Color
    if self.any(wHoverGrab):
      const mask = uint32 0x3FFFFFFF
      ctx.color(color0.toPacked and mask)
      ctx.fill(rect)
    # Fill Contrast Color
    calc = offset + offset * 0.5
    ctx.color(color1.toPacked)
    # Prepare Triangle Points
    var
      p0 = point(rect.x, rect.y)
      p1 = point(rect.x, rect.yh)
      p2 = point(rect.x + calc, rect.yh - offset)
    # Draw Left Triangle
    ctx.triangle(p0, p1, p2)
    # Draw Right Triangle
    p0.x = rect.xw
    p1.x = rect.xw
    p2.x = rect.xw - calc
    ctx.triangle(p2, p1, p0)

  method draw(ctx: ptr CTXRender) =
    self.drawHue(ctx)
    self.drawCursor(ctx)

  method event(state: ptr GUIState) =
    let
      rect = addr self.rect
      delta = (state.my - rect.y) / rect.h
      t = clamp(delta, 0, 1)
    # Change Hue Interpolation
    if (state.kind == evCursorClick) or self.test(wGrab):
      self.hsv.h = t

# ----------------
# Color Hue Circle
# ----------------

widget GUIHue0Circle of GUIColor0Base:
  attributes:
    clicked: bool

  new hue0circle(hsv: ptr HSVColor, slave = false):
    result.hsv = hsv
    result.slave = slave
    result.flags = wMouse

  proc drawHue(ctx: ptr CTXRender) =
    let
      rect = addr self.rect
      r = rect(self.rect)
      # Calculate Aspect Ratio
      ra0 = 0.5 * float32 min(rect.w, rect.h)
      ra1 = ra0 * 0.75
      # Locate Center Point
      cx = (r.x + r.xw) * 0.5
      cy = (r.y + r.yh) * 0.5
      # Find Number or Sides
      n = int32(1 shl ra0.log2.int) shr 1
      rcp = 1.0 / float32(n)
      theta = 2 * PI * rcp
    var
      hue = HSVColor(h: 0.0, s: 1.0, v: 1.0)
      # Circle Position
      x, y: float32
      o, ox, oy: float32
      # Elements
      i, j, k: int32
    # Reserve Points
    ctx.addVerts(n shl 2, n * 18)
    # Batch Circle Points
    while i < n:
      # Calculate Color
      ctx.color(hue.toRGB.toPacked)
      # Direction Normals
      ox = cos(o); oy = sin(o)
      # Point Position
      block: # Outer Vertex
        x = cx + ox * ra0
        y = cy + oy * ra0
        # Outer Vertex
        ctx.vertex(j, x, y)
        ctx.vertexAA(j + 1, x + ox, y + oy)
      block: # Inner Vertex
        x = cx + ox * ra1
        y = cy + oy * ra1
        ctx.vertex(j + 2, x, y)
        ctx.vertexAA(j + 3, x - ox, y - oy)
      # Triangle Elements
      if i + 1 < n:
        ctx.quad(k + 0, j, j + 4, j + 6, j + 2)
        ctx.quad(k + 6, j, j + 1, j + 5, j + 4)
        ctx.quad(k + 12, j + 2, j + 6, j + 7, j + 3)
      else: # Last With First
        ctx.quad(k + 0, j, 0, 2, j + 2)
        ctx.quad(k + 6, j, j + 1, 1, 0)
        ctx.quad(k + 12, j + 2, 2, 3, j + 3)
      # Next Circle Triangle
      i += 1; j += 4; k += 18
      # Next Angle Hue
      hue.h += rcp
      o += theta

  proc drawCursor(ctx: ptr CTXRender) =
    let
      rect = addr self.rect
      r = rect(self.rect)
      # Calculate Aspect Ratio
      radius = float32 min(rect.w, rect.h)
      ra0 = 0.4375 * radius
      ra1 = 0.05 * radius
      # Get Color
      app = getApp()
      h = self.hsv.h
      hsv = HSVColor(h: h, s: 1.0, v: 1.0)
      # Colors
      rgb = hsv.toRGB
      item = toRGB app.colors.item
      color0 = contrast(item, rgb)
      # Cursor Location
      rad = 2 * PI * h
      x = (r.x + r.xw) * 0.5 + cos(rad) * ra0
      y = (r.y + r.yh) * 0.5 + sin(rad) * ra0
      # Create Point
      p = point(x, y)
    # Render Color Circles
    ctx.color color0.toPacked
    ctx.circle(p, ra1)
    ctx.color rgb.toPacked
    ctx.circle(p, ra1 * 0.75)

  method draw(ctx: ptr CTXRender) =
    ctx.fill rect(self.rect)
    self.drawHue(ctx)
    self.drawCursor(ctx)
    ctx.color 0xFFFFFFFF'u32

  method event(state: ptr GUIState) =
    let
      rect = addr self.rect
      radius = float32 min(rect.w, rect.h)
      r = rect(self.rect)
      # Radius Range
      ra0 = 0.5 * radius
      ra1 = 0.75 * ra0
      # Check Distance
      dx = float32(state.mx) - (r.x + r.xw) * 0.5
      dy = float32(state.my) - (r.y + r.yh) * 0.5
    # Clicked Test
    var clicked = self.clicked
    # Check if Inside Circle
    if state.kind == evCursorClick:
      let dist = dx * dx + dy * dy
      clicked = dist >= ra1 * ra1 and dist <= ra0 * ra0
    # Calculate Cursor Angle
    elif self.test(wGrab) and clicked:
      var angle = arctan2(dy, dx)
      if angle < 0.0:
        angle += 2 * PI
      self.hsv.h = angle / PI * 0.5
    else: clicked = false
    # Replace Clicked
    self.clicked = clicked

