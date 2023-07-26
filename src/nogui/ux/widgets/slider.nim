import ../prelude
from strutils import 
  formatFloat, ffDecimal
from ../../values import
  Value, toRaw, lerp, discrete, toFloat, toInt

widget GUISlider:
  attributes:
    value: ptr Value
    decimals: int8

  new slider(value: ptr Value, decimals = 0'i8):
    let height = getApp().font.height
    # Widget Standard Flag
    result.flags = wMouse
    # Set Minimun Size
    result.minimum(0, height)
    # Set Widget Attributes
    result.value = value
    result.decimals = decimals

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      colors = addr app.colors
      rect = addr self.rect
    block: # Draw Slider
      var r = rect(self.rect)
      # Fill Slider Background
      ctx.color(colors.darker)
      ctx.fill(r)
      # Get Slider Width and Fill Slider Bar
      r.xw = r.x + float32(rect.w) * self.value[].toRaw
      ctx.color self.itemColor()
      ctx.fill(r)
    # Draw Text Information
    let text = 
      if self.decimals > 0:
        formatFloat(self.value[].toFloat, 
          ffDecimal, self.decimals)
      else: $self.value[].toInt
    ctx.color(colors.text)
    ctx.text( # On The Right Side
      rect.x + rect.w - text.width - 4, 
      rect.y - app.font.desc, text)

  method event(state: ptr GUIState) =
    if self.test(wGrab):
      let 
        rect = addr self.rect
        t = (state.mx - rect.x) / rect.w
        value = self.value
      # Change Value
      if self.decimals > 0:
        value[].lerp(t)
      else: value[].discrete(t)
