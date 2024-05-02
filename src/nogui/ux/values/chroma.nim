from math import floor
# RGB/HSV Color Chroma

type
  RGBColor* = object
    r*, g*, b*: float32
  HSVColor* = object
    h*, s*, v*: float32

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
