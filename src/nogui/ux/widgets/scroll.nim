import ../prelude
import ../values/scroller

widget UXScroll:
  attributes:
    value: & Scroller
    [pos, p]: float32
    # Scroll Orientation
    vertical: bool

  new scrollbar(value: & Scroller, vertical: bool):
    # Widget Standard Flag
    result.flags = {wMouse}
    # Set Widget Attributes
    result.value = value
    result.vertical = vertical

  method update =
    let size = getApp().font.baseline
    # Set Minimun Size
    self.minimum(size, size)

  proc viewbar(size: int32): tuple[x, w: float32] =
    let
      m0 = float32(getApp().font.asc shr 1)
      value = peek(self.value)
      # Scroller Values
      t = value[].raw
      v0 = value[].view
      w0 = value[].width
      # Scroller Thick
      s = float32(size)
      factor = s / w0
      thick = clamp(factor * v0, m0, s)
    # Calculate Thick Size
    result.w = thick
    result.x = t * (s - thick)

  method draw(ctx: ptr CTXRender) =
    let
      colors = addr getApp().colors
      region = addr self.rect
    # Fill Background
    var r = rect region[]
    ctx.color(colors.darker)
    ctx.fill(r)
    # Calculate Scroller
    if self.vertical:
      let v = self.viewbar(region.h)
      r.y0 += v.x; r.y1 = r.y0 + v.w
    else: # Horizontal Viewbar
      let v = self.viewbar(region.w)
      r.x0 += v.x; r.x1 = r.x0 + v.w
    # Draw Scroller
    ctx.color self.itemColor()
    ctx.fill(r)

  method event(state: ptr GUIState) =
    if not self.test(wGrab): return
    let rect = addr self.rect
    var pos, p, side: float32
    # Calculate Viewbar Size
    let v = if self.vertical:
      pos = state.py - float32(rect.y)
      side = float32(rect.h)
      self.viewbar(rect.h)
    else: # Horizontal Viewbar
      pos = state.px - float32(rect.x)
      side = float32(rect.w)
      self.viewbar(rect.w)
    # Calculate Scroller Pivot
    let
      value = react(self.value)
      factor = value[].rem / (side - v.w)
    if state.kind == evCursorClick:
      let half = v.w * 0.5
      p = value[].position
      # Locate Outside Position
      if pos < v.x or pos > v.x + v.w:
        p = (pos - half) * factor
        value[].position(p)
      # Set Current Pivot
      self.pos = pos
      self.p = p
      return
    # Set Scroller Value Difference
    pos = (pos - self.pos) * factor
    value[].position(self.p + pos)
