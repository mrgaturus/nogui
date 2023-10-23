# TODO: event propagation will make work again with ptr
from math import cos, sin, sqrt, PI
import base

# ---------------------
# Saturate/Value Square
# ---------------------

widget UXColor0Square:
  attributes:
    hsv: & HSVColor
    
  new sv0square(hsv: & HSVColor):
    result.hsv = hsv
    result.flags = wMouse
    # Minimun Width Size
    let w = getApp().font.height
    result.minimum(w, w)

  proc drawSV(ctx: ptr CTXRender) =
    let 
      rect = rect(self.rect)
      hsv = peek(self.hsv)
      color0 = HSVColor(h: hsv.h, s: 1.0, v: 1.0)
      color1 = color0.toRGB.toPacked
    # Reserve Vertex
    ctx.addVerts(8, 12)
    # White/Color Gradient
    ctx.vertexCOL(0, rect.x, rect.y, WHITE)
    ctx.vertexCOL(1, rect.xw, rect.y, color1)
    ctx.vertexCOL(2, rect.x, rect.yh, WHITE)
    ctx.vertexCOL(3, rect.xw, rect.yh, color1)
    # White/Color Elements
    ctx.triangle(0, 0,1,2)
    ctx.triangle(3, 1,2,3)
    # Black/Color Gradient
    ctx.vertexCOL(4, rect.x, rect.y, 0)
    ctx.vertexCOL(5, rect.xw, rect.y, 0)
    ctx.vertexCOL(6, rect.x, rect.yh, BLACK)
    ctx.vertexCOL(7, rect.xw, rect.yh, BLACK)
    # Black/Color Elements
    ctx.triangle(6, 4,5,6)
    ctx.triangle(9, 5,6,7)
    # 3 -- Draw Color Bar
    ctx.addVerts(14, 36)

  proc drawCursor(ctx: ptr CTXRender) =
    let
      app = getApp()
      hsv = peek(self.hsv)
      s = hsv.s
      v = 1.0 - hsv.v
      # Colors
      rgb = hsv[].toRGB
      item = toRGB app.colors.item
      color0 = contrast(item, rgb)
      size = float32 getApp().font.asc shr 1
      # Cursor Location
      rect = rect self.rect
      x = rect.x + (rect.xw - rect.x) * s
      y = rect.y + (rect.yh - rect.y) * v
      # Create Point
      p = point(x, y)
    # Render Color Circles
    ctx.color color0.toPacked
    ctx.circle(p, size)
    ctx.color rgb.toPacked
    ctx.circle(p, size * 0.75)

  method draw(ctx: ptr CTXRender) =
    self.drawSV(ctx)
    # Draw Selected Color
    self.drawCursor(ctx)

  method event(state: ptr GUIState) =
    let 
      x = (state.mx - self.rect.x) / self.rect.w
      y = (state.my - self.rect.y) / self.rect.h
    if (state.kind == evCursorClick) or self.test(wGrab):
      let hsv = react(self.hsv)
      hsv.s = clamp(x, 0, 1)
      hsv.v = clamp(1 - y, 0, 1)

# ----------------------
# Triangle Helpers Procs
# ----------------------

type
  SV0Triangle = array[3, CTXPoint]
  SV0TriangleEQ = array[3, float32]

proc equation(a, b: CTXPoint): SV0TriangleEQ =
  result[0] = a.y - b.y
  result[1] = b.x - a.x
  # useful for triangle Area
  result[2] = a.x * b.y - b.x * a.y

proc calc(eq: SV0TriangleEQ, x, y: float32): float32 =
  x * eq[0] + y * eq[1] + eq[2]

proc xymap*(tri: SV0Triangle, x, y: float32): CTXPoint =
  # Equation Creation
  let
    eq0 = equation(tri[1], tri[2])
    eq1 = equation(tri[2], tri[0])
    eq2 = equation(tri[0], tri[1])
    area = eq0[2] + eq1[2] + eq2[2]
  let 
    e0 = eq0.calc(x, y)
    e2 = eq2.calc(x, y)
  # Evaluate Saturation Value
  result.y = (e0 + e2) / area
  result.x = e2 / result.y / area

proc uvmap(tri: SV0Triangle, u, v: float32): CTXPoint =
  let uv = u * v
  # Interpolate Each Position
  template mix(a, b, c: float32): float32 =
    b + v * (c - b) + uv * (a - c)
  result.x = mix(tri[0].x, tri[1].x, tri[2].x)
  result.y = mix(tri[0].y, tri[1].y, tri[2].y)

# -----------------------
# Saturate/Value Triangle
# -----------------------

widget UXColor0Triangle:
  attributes:
    hsv: & HSVColor

  new sv0triangle(hsv: & HSVColor):
    result.hsv = hsv
    result.flags = wMouse
    # Minimun Width Size
    let w = getApp().font.height
    result.minimum(w, w)

  proc triangle*: SV0Triangle =
    const 
      pi2 = 2.0 * PI
      pi2div3 = pi2 / 3.0
    # Calculate Center and Radius
    let
      rect = addr self.rect
      r = rect rect[]
      radius = 0.5 * float32 min(rect.w, rect.h)
      # Calculate Center
      cx = (r.x + r.xw) * 0.5
      cy = (r.y + r.yh) * 0.5
      # Initial Angle
      angle = peek(self.hsv).h * pi2
    # Calculate Triangles
    var ox, oy, theta: float32
    for i in 0 ..< 3:
      # 0 -> s = 1.0 v = 1.0
      # 1 -> s = 0.0 v = 0.0
      # 2 -> s = 0.0 v = 1.0
      ox = cos(angle + theta) * radius
      oy = sin(angle + theta) * radius
      result[i] = point(cx + ox, cy + oy)
      # Step Angle Offset
      theta += pi2div3

  proc drawCursor(ctx: ptr CTXRender, p: CTXPoint) =
    let
      app = getApp()
      # Colors
      rgb = peek(self.hsv)[].toRGB
      item = toRGB app.colors.item
      color0 = contrast(item, rgb)
      size = float32 getApp().font.asc shr 1
    # Render Color Circles
    ctx.color color0.toPacked
    ctx.circle(p, size)
    ctx.color rgb.toPacked
    ctx.circle(p, size * 0.75)

  method draw(ctx: ptr CTXRender) =
    # Calculate Triangle
    let
      hsv = peek(self.hsv)
      tri = self.triangle()
      p = tri.uvmap(hsv.s, hsv.v)
      h = hsv.h
    # Calculate Color Corners
    var hc: array[3, GUIColor]
    block: # Avoid so much objects
      hc[0] = HSVColor(h: h, s: 1.0, v: 1.0).toRGB.toPacked
      hc[1] = HSVColor(h: h, s: 0.0, v: 0.0).toRGB.toPacked
      hc[2] = HSVColor(h: h, s: 0.0, v: 1.0).toRGB.toPacked
    # Reserve Triangle
    ctx.addVerts(9, 21)
    #ctx.addVerts(3, 3)
    # Draw Base Triangle
    ctx.vertexCOL(0, tri[0].x, tri[0].y, hc[0])
    ctx.vertexCOL(1, tri[1].x, tri[1].y, hc[1])
    ctx.vertexCOL(2, tri[2].x, tri[2].y, hc[2])
    ctx.triangle(0, 0, 1, 2)
    # Draw Antialiasing
    var i: int32
    while i < 3:
      let 
        j = (i + 1) mod 3
        k = int32 (i shl 1) + 3
        # Lookup Normals
        a = tri[i]
        b = tri[j]
      var norm = normal(b, a)
      norm.x *= 1.5
      norm.y *= 1.5
      # Create Antialiasing
      ctx.vertexCOL(k, a.x + norm.x, a.y + norm.y, 0)
      ctx.vertexCOL(k + 1, b.x + norm.x, b.y + norm.y, 0)
      ctx.quad(3 + i * 6, i, k, k + 1, j)
      # Next Index
      inc(i)
    # Draw Location
    self.drawCursor(ctx, p)

  method event(state: ptr GUIState) =
    let 
      x = float32 state.mx
      y = float32 state.my
    if (state.kind == evCursorClick) or self.test(wGrab):
      let p = self.triangle().xymap(x, y)
      # Clamp Saturation Value
      var 
        v = min(p.y, 1.0)
        s = clamp(1.0 - p.x, 0, 1)
      if v <= 0: 
        v = 0.0
        s = 1.0 - s
      # Replace Saturation Value
      let hsv = react(self.hsv)
      hsv.s = s
      hsv.v = v
