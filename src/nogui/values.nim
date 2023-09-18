from math import floor, ceil, round

type
  Lerp* = object
    min, max: float32
    # Interpolation
    dist, t: float32
  LerpSlice = HSlice[float32, float32]
  # Color Models
  RGBColor* = object
    r*, g*, b*: float32
  HSVColor* = object
    h*, s*, v*: float32

# ------------------------
# Numeric Lerp Calculation
# ------------------------

proc toFloat*(n: Lerp): float32 =
  n.min + n.dist * n.t

proc toRaw*(n: Lerp): float32 {.inline.} = 
  result = n.t

proc toInt*(n: Lerp): int32 {.inline.} =
  result = int32(n.toFloat)

# ---------------------
# Numeric Lerp Interval
# ---------------------

proc interval*(n: var Lerp, min, max: sink float32) =
  # Set Min and Max Values
  if min > max:
    swap(min, max)
  # Clamp Value to Range
  let 
    dist = max - min
    v = n.dist * n.t
  # Set Current Value
  n.t = clamp(v, 0.0, dist) / dist
  # Set Current Interval
  n.max = max
  n.min = min
  n.dist = dist

proc interval*(n: var Lerp, max: sink float32) {.inline.} =
  interval(n, 0.0, max)

proc interval*(n: var Lerp, r: LerpSlice) {.inline.} =
  interval(n, r.a, r.b)

# -------------------
# Numeric Lerp Bounds
# -------------------

proc bounds*(n: Lerp): tuple[max, min: float32] =
  result = (n.max, n.min)

proc distance*(n: Lerp): float32 {.inline.} =
  result = n.dist

# --------------------------
# Numeric Lerp Interpolation
# --------------------------

proc discrete*(n: var Lerp, t: float32) =
  let
    t0 = clamp(t, 0.0, 1.0)
    dist = n.dist
  # Set Discretized Parameter
  n.t = round(dist * t0) / dist

proc lerp*(n: var Lerp, t: float32) =
  # Set Continious Parameter
  n.t = clamp(t, 0.0, 1.0)

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
