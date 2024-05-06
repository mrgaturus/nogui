type
  Scroller* = object
    w0, w1: float32
    pos, t: float32

proc adjust(scroll: var Scroller) =
  let rem = max(0, scroll.w0 - scroll.w1)
  scroll.pos = clamp(scroll.pos, 0, rem)
  # Calculate Interpolator
  var t: float32
  if rem > 0.0:
    t = scroll.pos / rem
  # Store Interpolator
  scroll.t = t

# ------------------------
# Linear Scroll Converters
# ------------------------

proc position*(scroll: Scroller): float32 {.inline.} =
  scroll.pos

proc raw*(scroll: Scroller): float32 {.inline.} =
  scroll.t

# -- Scroller Sizes --
proc width*(scroll: Scroller): float32 {.inline.} =
  scroll.w0

proc view*(scroll: Scroller): float32 {.inline.} =
  scroll.w1

proc rem*(scroll: Scroller): float32 {.inline.} =
  scroll.w0 - scroll.w1

proc scale*(scroll: Scroller): float32 =
  if scroll.w0 > 0.0:
    result = scroll.w1 / scroll.w0

# ------------------------
# Linear Scroll Definition
# ------------------------

proc width*(scroll: var Scroller, w: float32) =
  scroll.w0 = w
  scroll.adjust()

proc view*(scroll: var Scroller, w: float32) =
  scroll.w1 = w
  scroll.adjust()

proc scroller*(width, view: float32): Scroller =
  result.w0 = width
  result.w1 = view

# --------------------------
# Linear Scroll Interpolator
# --------------------------

proc position*(scroll: var Scroller, pos: float32) =
  scroll.pos = pos
  scroll.adjust()
