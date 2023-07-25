import ../widget, ../render
from strutils import 
  formatFloat, ffDecimal
from ../../values import
  Value, toRaw, lerp, discrete, toFloat, toInt
from ../event import GUIState
from ../config import 
  metrics, theme
from ../atlas import width
from ../../builder import widget

widget GUISlider:
  attributes:
    value: ptr Value
    decimals: int8

  new slider(value: ptr Value, decimals: int8):
    # Widget Standard Flag
    result.flags = wMouse
    # Set Minimun Size
    result.minimum(0, metrics.fontSize)
    # Set Widget Attributes
    result.value = value
    result.decimals = decimals

  method draw(ctx: ptr CTXRender) =
    block: # Draw Slider
      var rect = rect(self.rect)
      # Fill Slider Background
      ctx.color(theme.bgWidget)
      ctx.fill(rect)
      # Fill Slider Bar
      rect.xw = # Get Slider Width
        rect.x + float32(self.rect.w) * self.value[].toRaw
      ctx.color: # Status Color
        if not self.any(wHoverGrab):
          theme.barScroll
        elif self.test(wGrab):
          theme.grabScroll
        else: theme.hoverScroll
      ctx.fill(rect)
    # Draw Text Information
    let text = 
      if self.decimals > 0:
        formatFloat(self.value[].toFloat, 
          ffDecimal, self.decimals)
      else: $self.value[].toInt
    ctx.color(theme.text)
    ctx.text( # On The Right Side
      self.rect.x + self.rect.w - text.width - 4, 
      self.rect.y - metrics.descender, text)

  method event(state: ptr GUIState) =
    if self.test(wGrab):
      let 
        t = (state.mx - self.rect.x) / self.rect.w
        value = self.value
      # Change Value
      if self.decimals > 0:
        value[].lerp(t)
      else: value[].discrete(t)
