from math import
  floor, ceil, round,
  log2, pow

type
  LinearDual* = object
    min, max: float32 # Range
    k, t: float32 # Interpolation

# ----------------------
# Linear Dual Converters
# ----------------------

proc toFloat*(n: LinearDual): float32 =
  # Calculate Adjusted Interpolation
  n.min + (n.max - n.min) * pow(n.t, n.k)

proc toInt*(n: LinearDual): int32 {.inline.} =
  result = int32(n.toFloat)

proc toRaw*(n: LinearDual): float32 {.inline.} = 
  result = n.t

proc toRawPow*(n: LinearDual): float32 {.inline.} = 
  result = pow(n.t, n.k)

# -- Inverse Converter --
proc toNormal*(n: LinearDual, v: float32, dv = 0.0): float32 =
  var v1 = v + dv
  let delta = n.max - n.min
  # Calculate Normalized Interpolation
  if delta > 0.0 and n.k > 0.0:
    result = (v1 - n.min) / delta
    result = clamp(result, 0.0, 1.0)
    result = pow(result, 1.0 / n.k)

# ----------------------
# Linear Dual Definition
# ----------------------

# -- Definition --
proc bounds*(n: var LinearDual, min, mid, max: sink float32) =
  var v = n.toFloat()
  # Set Min and Max Values
  if min > max:
    swap(min, max)
  # Clamp Mid Value
  const ep = 1e-16
  mid = clamp(mid, min + ep, max)
  # Set Current Interval
  n.max = max
  n.min = min
  # Calculate K Adjust
  let delta = mid - min
  if delta > 0.0:
    let k = (max - min) / delta
    n.k = log2(k)
    # Restore Current Value
    n.t = n.toNormal(v)

proc dual*(min, mid, max: float32): LinearDual {.inline.} =
  result.bounds(min, mid, max)

proc dual*(min, max: float32): LinearDual =
  let mid = (max + min) * 0.5
  result.bounds(min, mid, max)

# -----------------------
# Linear Dual Information
# -----------------------

proc bounds*(n: LinearDual): tuple[max, min: float32] =
  result = (n.max, n.min)

proc distance*(n: LinearDual): float32 {.inline.} =
  result = n.max - n.min

# ------------------------
# Linear Dual Interpolator
# ------------------------

proc discrete*(n: var LinearDual, t: float32) =
  n.t = clamp(t, 0.0, 1.0)
  # Calculate Value
  let v = round(n.toFloat)
  n.t = n.toNormal(v)

proc lerp*(n: var LinearDual, t: float32) =
  # Set Continuous Parameter
  n.t = clamp(t, 0.0, 1.0)

proc lorp*(n: var LinearDual, v: float32) {.inline.} =
  # Set Continuous Parameter
  n.lerp n.toNormal(v)
