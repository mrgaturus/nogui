import ../native/ffi
from math import sqrt

type
  GUIStatePivot* = object
    locked*: bool
    # Pivot Position
    px*, py*: float32
    mx*, my*: int32
    # Pivot Difference
    dx*, dy*: float32
    dist*, away*: float32
    # Click Counter
    clicks*: int32
    stamp: GUINativeTime
    # Capture Keyboard
    key*, button*: GUIKeycode
    mods*: GUIKeymods

# ---------------------------
# GUI State Capture Auxiliars
# ---------------------------

proc timeout(pivot: var GUIStatePivot, renew: bool) =
  let
    ms500 = nogui_time_ms(500)
    now = nogui_time_now()
  # TODO: native double click interval
  if now > pivot.stamp + ms500:
    pivot.clicks = 0
  # Capture Timestamp
  if renew:
    pivot.stamp = now

proc click(pivot: var GUIStatePivot, state: ptr GUIState) =
  # Set Pivot Position
  pivot.px = state.px
  pivot.py = state.py
  pivot.mx = state.mx
  pivot.my = state.my
  # Capture Mouse Button and Mods
  pivot.button = state.key
  pivot.mods = state.mods
  # Capture Click Counter
  pivot.timeout(renew = true)
  inc(pivot.clicks)

proc distance(pivot: var GUIStatePivot, state: ptr GUIState) =
  let
    dx = state.px - pivot.px
    dy = state.py - pivot.py
    dist = sqrt(dx * dx + dy * dy)
  # Update Distance Lenght
  pivot.dist = dist
  pivot.away = max(pivot.away, dist)
  # Update Distance
  pivot.dx = dx
  pivot.dy = dy

# -----------------
# GUI State Capture
# -----------------

proc capture*(pivot: var GUIStatePivot, state: ptr GUIState) =
  case state.kind
  of evCursorClick:
    pivot.click(state)
    pivot.locked = true
  of evCursorRelease:
    pivot.dist = 0
    pivot.away = 0
    pivot.locked = false
    # Check Clicks Timeout
    pivot.timeout(renew = false)
  # Capture Distance
  of evCursorMove:
    if pivot.locked:
      pivot.distance(state)
    # Check Clicks Timeout
    pivot.timeout(renew = false)
  # Capture Keyboard Key
  of evKeyDown:
    if not pivot.locked:
      pivot.key = state.key
      pivot.mods = state.mods
  of evKeyUp:
    if not pivot.locked:
      pivot.key = NK_Unknown
      pivot.mods = state.mods
  # Skip Other Events
  else: discard
