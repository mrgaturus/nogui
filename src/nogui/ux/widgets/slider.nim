import ../prelude
from strutils import 
  formatFloat, ffDecimal
from ../../values import
  Lerp, toRaw, lerp, discrete, toFloat, toInt

widget UXSlider:
  attributes:
    value: ptr Lerp
    decimals: int8

  new slider(value: ptr Lerp, decimals = 0'i8):
    # Widget Standard Flag
    result.flags = wMouse
    # Set Widget Attributes
    result.value = value
    result.decimals = decimals

  method update =
    let size = getApp().font.height
    # Set Minimun Size
    self.minimum(size, size)

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      font = addr app.font
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
      rect.x + rect.w - text.width - (font.size shr 1),
      rect.y - font.desc, text)

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
