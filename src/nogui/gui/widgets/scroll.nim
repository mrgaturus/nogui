import ../widget, ../render
from ../../values import
  Value, toRaw, lerp,
  distance, toFloat, toInt
from ../event import 
  GUIState, GUIEvent
from ../config import 
  metrics, theme
from ../../builder import widget

widget GUIScroll:
  attributes:
    value: ptr Value
    [gp, gd]: float32
    vertical: bool

  new scrollbar(value: ptr Value, vertical: bool):
    # Widget Standard Flag
    result.flags = wMouse
    # Set Minimun Size
    result.minimum( # The Same as Font Size
      metrics.fontSize, metrics.fontSize)
    # Set Widget Attributes
    result.value = value
    result.vertical = vertical

  method draw(ctx: ptr CTXRender) =
    let value = self.value
    var rect = rect(self.rect)
    # Fill Background
    ctx.color(theme.bgScroll)
    ctx.fill(rect)
    block: # Fill Scroll Bar
      var side, scroll: float32
      let
        dist = value[].distance
        t = value[].toRaw
      # Draw Scroller
      if self.vertical:
        side = float32(self.rect.h)
        scroll = max(side / dist, 10)
        rect.y += # Move Scroll to distance
          (side - scroll) * t
        rect.yh = rect.y + scroll
      else: # Horizontal
        side = float32(self.rect.w)
        scroll = max(side / dist, 10)
        rect.x += # Move Scroll to distance
          (side - scroll) * t
        rect.xw = rect.x + scroll
    # Draw Scroll Bar
    ctx.color:
      if not self.any(wHoverGrab):
        theme.barScroll
      elif self.test(wGrab):
        theme.grabScroll
      else: theme.hoverScroll
    ctx.fill(rect)

  method event(state: ptr GUIState) =
    let 
      value = self.value
      dist = value[].distance
      t = value[].toRaw
    # Scroller Events
    if state.kind == evCursorClick:
      self.gp = float32:
        if self.vertical:
          state.my
        else: state.mx
      self.gd = t
    elif self.test(wGrab):
      var pos, side: float32
      if self.vertical:
        pos = float32(state.my)
        side = float32(self.rect.h)
      else: # Horizontal
        pos = float32(state.mx)
        side = float32(self.rect.w)
      side -= # Dont Let Scroll Be Too Small
        max(side / dist, 10)
      # Set Value
      value[].lerp (pos - self.gp) / side + self.gd
