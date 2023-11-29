from math import
  floor, ceil, round,
  log2, pow

type
  Lerp* = object
    min, max: float32
    # Interpolation
    dist, t: float32
  Lerp2* = object
    min, max: float32
    # Interpolation
    k, t: float32
  # Color Models
  RGBColor* = object
    r*, g*, b*: float32
  HSVColor* = object
    h*, s*, v*: float32

# -------------------
# Single Numeric Lerp
# -------------------

# -- Converters --
proc toFloat*(n: Lerp): float32 =
  n.min + n.dist * n.t

proc toInt*(n: Lerp): int32 {.inline.} =
  result = int32(n.toFloat)

proc toRaw*(n: Lerp): float32 {.inline.} = 
  result = n.t

# -- Inverse Converter --
proc toNormal*(n: Lerp, v: float32, dv = 0.0): float32 =
  let 
    v1 = v + dv
    dist = n.dist
  # Calculate Interpolation
  if dist > 0.0:
    result = (v1 - n.min) / dist

# -- Definition --
proc interval*(n: var Lerp, min, max: sink float32) =
  # Set Min and Max Values
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

proc interval*(n: var Lerp, max: float32) {.inline.} =
  interval(n, 0.0, max)

proc lerp*(min, max: float32): Lerp {.inline.} =
  result.interval(min, max)

# -- Information --
proc bounds*(n: Lerp): tuple[max, min: float32] =
  result = (n.max, n.min)

proc distance*(n: Lerp): float32 {.inline.} =
  result = n.dist

# -- Interpolator --
proc discrete*(n: var Lerp, t: float32) =
  let
    t0 = clamp(t, 0.0, 1.0)
    dist = n.dist
  # Set Discretized Parameter
  if dist > 0.0:
    n.t = round(dist * t0) / dist

# -- TODO: better naming --
proc lerp*(n: var Lerp, t: float32) =
  # Set Continuous Parameter
  n.t = clamp(t, 0.0, 1.0)

proc lorp*(n: var Lerp, v: float32) {.inline.} =
  # Set Continuous Parameter
  n.lerp n.toNormal(v)

# -----------------
# Dual Numeric Lerp
# -----------------

# -- Inverse Converter --
proc toNormal*(n: Lerp2, v: float32, dv = 0.0): float32 =
  var v1 = v + dv
  let delta = n.max - n.min
  # Calculate Normalized Interpolation
  if delta > 0.0 and n.k > 0.0:
    result = (v1 - n.min) / delta
    result = clamp(result, 0.0, 1.0)
    result = pow(result, 1.0 / n.k)

# -- Converters --
proc toFloat*(n: Lerp2): float32 =
  # Calculate Adjusted Interpolation
  n.min + (n.max - n.min) * pow(n.t, n.k)

proc toInt*(n: Lerp2): int32 {.inline.} =
  result = int32(n.toFloat)

proc toRaw*(n: Lerp2): float32 {.inline.} = 
  result = n.t

proc toRawPow*(n: Lerp2): float32 {.inline.} = 
  result = pow(n.t, n.k)

# -- Definition --
proc interval*(n: var Lerp2, min, mid, max: sink float32) =
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

proc lerp2*(min, mid, max: float32): Lerp2 {.inline.} =
  result.interval(min, mid, max)

proc lerp2*(min, max: float32): Lerp2 =
  let mid = (max + min) * 0.5
  result.interval(min, mid, max)

# -- Information --
proc bounds*(n: Lerp2): tuple[max, min: float32] =
  result = (n.max, n.min)

proc distance*(n: Lerp2): float32 {.inline.} =
  result = n.max - n.min

# -- Interpolator --
proc discrete*(n: var Lerp2, t: float32) =
  n.t = clamp(t, 0.0, 1.0)
  # Calculate Value
  let v = round(n.toFloat)
  n.t = n.toNormal(v)

# -- TODO: better naming --
proc lerp*(n: var Lerp2, t: float32) =
  # Set Continuous Parameter
  n.t = clamp(t, 0.0, 1.0)

proc lorp*(n: var Lerp2, v: float32) {.inline.} =
  # Set Continuous Parameter
  n.lerp n.toNormal(v)

# --------------------
# RGB/HSV Color Values
# --------------------

proc toRGB*(hsv: HSVColor): RGBColor =
  let v = hsv.v
  if hsv.s == 0:
    return RGBColor(r: v, g: v, b: v)
  # Convert RGB To HSV
  var a, b, c, h, f: float32
  # Hue Section
  h = hsv.h
  if h >= 1: h = 0
  h *= 6
  # Hue Index
  f = floor(h)
  let 
    i = int32 f
    s = hsv.s
  f = h - f
  # RGB Values
  a = v - v * s
  b = v - v * s * f
  c = v - v * (s - s * f)
  # Ajust Values Using Index
  case i:
  of 0: RGBColor(r: v, g: c, b: a)
  of 1: RGBColor(r: b, g: v, b: a)
  of 2: RGBColor(r: a, g: v, b: c)
  of 3: RGBColor(r: a, g: b, b: v)
  of 4: RGBColor(r: c, g: a, b: v)
  of 5: RGBColor(r: v, g: a, b: b)
  else: RGBColor(r: v, g: v, b: v)

proc toHSV*(rgb: RGBColor): HSVColor =
  let
    # Max and Min Color Channels
    max = max(rgb.r, rgb.g).max(rgb.b)
    min = min(rgb.r, rgb.g).min(rgb.b)
    # Color Channel Domain
    delta = max - min
  # Calculate Saturation/Value
  result.v = max
  if max > 0:
    result.s = delta / max
  if result.s == 0:
    return result
  # Calculate Hue
  if rgb.r == max:
    result.h = (rgb.g - rgb.b) / delta
  elif rgb.g == max:
    result.h = 2 + (rgb.b - rgb.r) / delta
  elif rgb.b == max:
    result.h = 4 + (rgb.r - rgb.g) / delta
  # Ajust Hue Range
  result.h *= 60
  if result.h < 0:
    result.h += 360
  result.h /= 360

# -----------------------
# RGB/Packed Color Values
# -----------------------

proc toPacked*(rgb: RGBColor): cuint =
  let
    r = cuint(rgb.r * 255.0)
    g = cuint(rgb.g * 255.0)
    b = cuint(rgb.b * 255.0)
  # Pack Color Channels to 32bit
  r or (g shl 8) or (b shl 16) or (0xFF shl 24)

proc toRGB*(rgb: cuint): RGBColor =
  const rcp = 1.0 / 0xFF
  result.r = float32(rgb and 0xFF) * rcp
  result.g = float32(rgb shr 8 and 0xFF) * rcp
  result.b = float32(rgb shr 16 and 0xFF) * rcp

# ---------------------
# FAST MATH C-FUNCTIONS
# ---------------------

{.emit: """

// -- nuklear_math.c
float inv_sqrt(float n) {
  float x2;
  const float threehalfs = 1.5f;
  union {unsigned int i; float f;} conv = {0};
  conv.f = n;
  x2 = n * 0.5f;
  conv.i = 0x5f375A84 - (conv.i >> 1);
  conv.f = conv.f * (threehalfs - (x2 * conv.f * conv.f));
  return conv.f;
}

float fast_sqrt(float n) {
  return n * inv_sqrt(n);
}

// -- Orthogonal Projection for GUI Drawing
void gui_mat4(float* r, float w, float h) {
  r[0] = 2.0 / w;
  r[5] = -2.0 / h;
  r[12] = -1.0;

  r[10] = r[13] = r[15] = 1.0;
}

""".}

# C to Nim Wrappers to Fast Math C-Functions
proc invSqrt*(n: float32): float32 {.importc: "inv_sqrt".}
proc fastSqrt*(n: float32): float32 {.importc: "fast_sqrt".}
proc guiProjection*(mat: ptr array[16, float32], w,h: float32) {.importc: "gui_mat4".}
