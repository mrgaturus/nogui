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
  new hue0circle(hsv: ptr HSVColor, slave = false):
    result.hsv = hsv
    result.slave = slave
    result.flags = wMouse

  method draw(ctx: ptr CTXRender) =
    discard

  method event(state: ptr GUIState) =
    discard
