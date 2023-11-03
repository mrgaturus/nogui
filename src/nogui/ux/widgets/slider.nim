import ../prelude
import ../../format
# Import Value Interpolation
from ../../values import
  Lerp, toRaw, lerp, discrete, toFloat, toInt

# ---------------------
# Lerp Formatting Procs
# ---------------------

type SliderFmtProc* =
  proc(s: ShallowString, v: Lerp) {.nimcall.}

# -- Easy Text Formatting --
template fmt0*(f: cstring): SliderFmtProc =
  proc (s: ShallowString, v: Lerp) =
    s.format(f, v.toInt)

template fmt1*(f: cstring): SliderFmtProc =
  proc (s: ShallowString, v: Lerp) =
    s.format(f, v.toFloat)

# -------------------------
# Widget Single Lerp Slider
# -------------------------

widget UXSlider:
  attributes:
    value: & Lerp
    # Format Slider
    fn: SliderFmtProc
    [z0, s0]: bool

  proc slider0(value: & Lerp, fn: SliderFmtProc, z0: bool) =
    # Widget Standard Flag
    self.flags = wMouse
    self.value = value
    # Value Manipulation
    self.z0 = z0
    self.fn = fn

  # -- Integer Format --
  new slider(value: & Lerp):
    result.slider0(value, fmt0"%d", true)

  # -- Customizable Format --
  new slider0float(value: & Lerp, fn: SliderFmtProc):
    result.slider0(value, fn, false)

  new slider0int(value: & Lerp, fn: SliderFmtProc):
    result.slider0(value, fn, true)

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
      # Slider Value
      fmt = app.fmt
      value = self.value.peek[]
    block: # Draw Slider
      var r = rect(self.rect)
      # Fill Slider Background
      ctx.color(colors.darker)
      ctx.fill(r)
      # Get Slider Width and Fill Slider Bar
      r.xw = r.x + float32(rect.w) * value.toRaw
      ctx.color self.itemColor()
      ctx.fill(r)
    # Calculate Text Format
    self.fn(fmt, value)
    let text = fmt.peek()
    # Draw Text Format
    ctx.color(colors.text)
    ctx.text( # On The Right Side
      rect.x + rect.w - text.width - (font.size shr 1),
      rect.y - font.desc, text)

  method event(state: ptr GUIState) =
    if self.test(wGrab):
      let 
        rect = addr self.rect
        t = (state.mx - rect.x) / rect.w
        value = self.value.react()
      # Change Value
      if self.z0:
        value[].discrete(t)
      else: value[].lerp(t)
