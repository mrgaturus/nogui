import ../prelude
import ../../format
# Import Value Interpolation
import ../values/[linear, dual]

# -----------------------
# Linear Formatting Procs
# -----------------------

type
  LinearFormat* =
    proc(s: ShallowString, v: Linear) {.nimcall.}
  Linear2Format* =
    proc(s: ShallowString, v: LinearDual) {.nimcall.}

# -- Single Linear Formatting --
template fmt*(f: cstring): LinearFormat =
  proc (s: ShallowString, v: Linear) =
    s.format(f, v.toInt)

template fmf*(f: cstring): LinearFormat =
  proc (s: ShallowString, v: Linear) =
    s.format(f, v.toFloat)

# -- Dual Linear Formatting --
template fmt2*(f: cstring): Linear2Format =
  proc (s: ShallowString, v: LinearDual) =
    s.format(f, v.toInt)

template fmf2*(f: cstring): Linear2Format =
  proc (s: ShallowString, v: LinearDual) =
    s.format(f, v.toFloat)

# ------------------------
# Widget Linear Event Commom
# ------------------------

template event0(self: typed, state: ptr GUIState) =
  let
    x = int16 state.mx
    rect = addr self.rect
    value = self.value.peek
  # Choose Slow Grab
  if state.kind == evCursorClick:
    let slow = # Check Slow Grab
      (Mod_Shift in state.mods) or 
      state.key == Button_Right
    # Store Initial Values
    if slow:
      self.v = value[].toFloat()
      self.x = x
    # Store Flag
    self.s0 = slow
  # Manipulate if Grabbed
  if self.test(wGrab):
    var t = (x - rect.x) / rect.w
    # Check Slow Flag
    if self.s0:
      let chunk = getApp().font.height
      # Calculate Slow Interpolant
      t = (x - self.x) / chunk * self.step
      t = value[].toNormal(self.v, t)
    # Change Value
    if self.z0:
      value[].discrete(t)
    else: value[].lerp(t)
    # Execute Changed Callback
    send(self.value.head.cb)

# --------------------
# Widget Linear Slider
# --------------------

widget UXSlider:
  attributes:
    value: & Linear
    # Slow Drag
    v: float32
    x: int16
    # Format Slider
    fn: LinearFormat
    [z0, s0]: bool
    # Misc Custom
    {.public.}:
      step: float32

  proc slider0(value: & Linear, fn: LinearFormat, z0: bool) =
    # Widget Standard Flag
    self.flags = {wMouse}
    self.value = value
    # Value Manipulation
    self.z0 = z0
    self.fn = fn
    # Default Slow Step
    self.step = 1.0

  # -- Integer Format --
  new slider(value: & Linear):
    result.slider0(value, fmt"%d", true)

  # -- Customizable Format --
  new slider0float(value: & Linear, fn: LinearFormat):
    result.slider0(value, fn, false)

  new slider0int(value: & Linear, fn: LinearFormat):
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
      r.x1 = r.x0 + float32(rect.w) * value.toRaw
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
    self.event0(state)

# -------------------------
# Widget Linear Dual Slider
# -------------------------

widget UXDualSlider:
  attributes:
    value: & LinearDual
    # Slow Drag
    v: float32
    x: int16
    # Format Slider
    fn: Linear2Format
    [z0, s0]: bool
    # Misc Custom
    {.public.}:
      step: float32
      center: float32

  proc dual0(value: & LinearDual, fn: Linear2Format, z0: bool) =
    # Widget Standard Flag
    self.flags = {wMouse}
    self.value = value
    # Value Manipulation
    self.z0 = z0
    self.fn = fn
    # Default Slow Step
    self.step = 0.03125

  # -- Integer Format --
  new dual(value: & LinearDual):
    result.dual0(value, fmt2"%d", true)

  # -- Customizable Format --
  new dual0float(value: & LinearDual, fn: Linear2Format):
    result.dual0(value, fn, false)

  new dual0int(value: & LinearDual, fn: Linear2Format):
    result.dual0(value, fn, true)

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
      t = value.toRaw * 2.0 - 1.0
    block: # Draw Dual Slider
      var r = rect(self.rect)
      # Fill Slider Background
      ctx.color(colors.darker)
      ctx.fill(r)
      # Add Slider Pad
      var pad = float32(font.height) * 0.25
      r.x0 += pad; r.y0 += pad
      r.x1 -= pad; r.y1 -= pad
      # Locate to Center
      r.x0 = (r.x0 + r.x1) * 0.5
      let half = r.x1 - r.x0
      r.x1 = r.x0 + half * t
      # Fill Slider
      ctx.color self.itemColor()
      ctx.fill(r)
      # Locate Mark
      r.x0 = r.x1
      pad *= 0.5
      # Apply Mark Pad
      r.x1 -= pad; r.x0 += pad
      r.y0 -= pad; r.y1 += pad
      # Fill Mark Pad
      ctx.color(colors.text)
      ctx.fill(r)
    # Calculate Text Format
    self.fn(fmt, value)
    let text = fmt.peek()
    var ox: int32 = font.size shr 1
    # Set Orientation
    if t <= 0.0:
      ox = rect.x + rect.w - ox - text.width
    else: ox = rect.x + ox
    # Draw Text Format
    ctx.color(colors.text)
    ctx.text(ox, rect.y - font.desc, text)

  method event(state: ptr GUIState) =
    self.event0(state)
    # Snap 0.5 When Dragging
    if self.test(wGrab) and not self.s0:
      let
        rect = addr self.rect
        value = self.value.peek
        # Calculate Center Interpolation
        cx = rect.x + (rect.w shr 1)
        pad = getApp().font.asc shr 2
        x = state.mx
      # Snap 0.5 When is in range
      if x < cx + pad and x > cx - pad:
        value[].lerp(0.5)
