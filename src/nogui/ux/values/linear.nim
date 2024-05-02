from math import round

type
  Linear* = object
    min, max: float32 # Bounds
    dist, t: float32 # Interpolation

# -----------------------
# Linear Value Converters
# -----------------------

proc toFloat*(n: Linear): float32 =
  n.min + n.dist * n.t

proc toInt*(n: Linear): int32 {.inline.} =
  result = int32(n.toFloat)

proc toRaw*(n: Linear): float32 {.inline.} = 
  result = n.t

# -- Inverse Converter --
proc toNormal*(n: Linear, v: float32, dv = 0.0): float32 =
  let 
    v1 = v + dv
    dist = n.dist
  # Calculate Interpolation
  if dist > 0.0:
    result = (v1 - n.min) / dist

# ---------------------
# Linear Value Interval
# ---------------------

proc bounds*(n: var Linear, min, max: sink float32) =
  # Set Mn and Max Values
  if min > max:
    swap(min, max)
  # Clamp Value to Range
  let 
    dist = max - min
    v = n.dist * n.t
  # Restore Current Value
  if dist > 0.0:
    n.t = clamp(v, 0.0, dist) / dist
  # Remove Value if Invalid
  else: n.t = 0.0
  # Set Current Interval
  n.max = max
  n.min = min
  n.dist = dist

proc linear*(min, max: float32): Linear {.inline.} =
  result.bounds(min, max)

proc linear*(max: float32): Linear {.inline.} =
  result.bounds(0, max)

# ------------------------
# Linear Value Information
# ------------------------

proc bounds*(n: Linear): tuple[max, min: float32] =
  result = (n.max, n.min)

proc distance*(n: Linear): float32 {.inline.} =
  result = n.dist

# --------------------------
# Linear Value Interpolation
# --------------------------

proc discrete*(n: var Linear, t: float32) =
  let
    t0 = clamp(t, 0.0, 1.0)
    dist = n.dist
  # Set Discretized Parameter
  if dist > 0.0:
    n.t = round(dist * t0) / dist

proc lerp*(n: var Linear, t: float32) =
  # Set Continuous Parameter
  n.t = clamp(t, 0.0, 1.0)

proc lorp*(n: var Linear, v: float32) {.inline.} =
  # Set Continuous Parameter
  n.lerp n.toNormal(v)
