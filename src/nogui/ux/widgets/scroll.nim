import ../prelude
from ../../values import
  Value, toRaw, lerp,
  distance, toFloat, toInt

widget UXScroll:
  attributes:
    value: ptr Value
    [pos, t]: float32
    # Scroll Orientation
    vertical: bool

  new scrollbar(value: ptr Value, vertical: bool):
    let height = getApp().font.asc
    # Widget Standard Flag
    result.flags = wMouse
    # Set Minimun Size
    result.minimum(height, height)
    # Set Widget Attributes
    result.value = value
    result.vertical = vertical

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      colors = addr app.colors
      height = float32(app.font.height)
      # Value Distance
      value = self.value
      dist = value[].distance
      t = value[].toRaw
      # Bound Rect
      region = addr self.rect
    var r = rect region[]
    # Fill Background
    ctx.color(colors.darker)
    ctx.fill(r)
    # Scroll Side Scaler
    template scroller(size: int32, x, w: var float32) =
      let 
        side = float32(size)
        factor = side * side / dist
        # Calculate Metrics
        scroll = clamp(factor, height, side)
        offset = side - scroll
      # Move Scroll to Distance
      x += t * offset
      w = x + scroll
    # Draw Scroller
    if self.vertical: 
      scroller(region.h, r.y, r.yh)
    else: scroller(region.w, r.x, r.xw)
    # Draw Scroll Bar
    ctx.color self.itemColor()
    ctx.fill(r)

  method event(state: ptr GUIState) =
    let
      value = self.value
      dist = value[].distance
      t = value[].toRaw
      rect = addr self.rect
    # Calculate Factor
    var pos, side, delta: float32
    if self.vertical:
      pos = float32 state.my
      delta = pos - float32 rect.y
      side = float32 rect.h
    else: # Horizontal
      pos = float32 state.mx
      delta = pos - float32 rect.x
      side = float32 rect.w
    # Calculate Scaling
    let 
      height = float32 getApp().font.height
      factor = side * side / dist
      # Calculate Metrics
      scroll = clamp(factor, height, side)
      offset = side - scroll
    # Scroller Events
    if state.kind == evCursorClick:
      self.pos = pos
      self.t = t
      # Locate Outside Position
      let to = t * offset
      if (delta < to or delta > to + scroll) and offset > 0.0:
        pos = (delta - scroll * 0.5) / offset
        # Change New Value
        value[].lerp pos
        self.t = pos
      # Store Grab State
    elif self.test(wGrab):
      # Set Interpolated Value
      if offset > 0.0:
        pos = (pos - self.pos) / offset
        value[].lerp self.t + pos
