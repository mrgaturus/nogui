import base

# ---------------------
# Saturate/Value Square
# ---------------------

widget GUIColor0Square of GUIColor0Base:
  new color0square(hsv: ptr HSVColor, slave = false):
    result.hsv = hsv
    result.slave = slave
    result.flags = wMouse
    # Minimun Width Size
    let w = getApp().font.height
    result.minimum(w, w)

  proc drawSV(ctx: ptr CTXRender) =
    let 
      rect = rect(self.rect)
      color0 = HSVColor(h: self.hsv.h, s: 1.0, v: 1.0)
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
      hsv = self.hsv
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
      self.hsv.s = clamp(x, 0, 1)
      self.hsv.v = clamp(1 - y, 0, 1)

# -----------------------
# Saturate/Value Triangle
# -----------------------

widget GUIColor0Triangle of GUIColor0Base:
  discard