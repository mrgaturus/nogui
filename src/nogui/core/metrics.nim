type
  GUIMetrics* = object
    x*, y*, w*, h*: int16
    # Dimensions Hint
    minW*, minH*: int16
    maxW*, maxH*: int16
  GUIRect* = object
    x*, y*, w*, h*: int32
  # Clipping Levels
  GUIClipping* = object
    levels: seq[GUIRect]

# ----------------------
# Absolute Rect Clipping 
# ----------------------

proc intersect*(a, b: GUIRect): GUIRect =
  result.x = max(a.x, b.x)
  result.y = max(a.y, b.y)
  result.w = min(a.x + a.w, b.x + b.w) - result.x
  result.h = min(a.y + a.h, b.y + b.h) - result.y
  # Clamp Dimensions to 0
  if (result.w or result.h) < 0:
    result.w = 0
    result.h = 0

proc inside*(rect, clip: GUIRect): bool =
  rect.x <= clip.x + clip.w and
  rect.y <= clip.y + clip.h and
  rect.x + rect.w >= clip.x and
  rect.y + rect.h >= clip.y

proc push*(clip: var GUIClipping, rect: GUIRect) =
  if len(clip.levels) == 0:
    clip.levels.add(rect)
    return
  # Intersect With Last Rect
  let r = intersect(clip.levels[^1], rect)
  clip.levels.add(r)

proc pop*(clip: var GUIClipping) =
  let idx = max(high clip.levels, 0)
  setLen(clip.levels, idx)

proc peek*(clip: GUIClipping): GUIRect =
  let idx = high(clip.levels)
  # Peek Current Clipping
  if idx >= 0:
    result = clip.levels[idx]

proc clear*(clip: var GUIClipping) {.inline.} =
  setLen(clip.levels, 0)

# ------------------------
# Relative Metrics Helpers 
# ------------------------

proc minfit*(m: var GUIMetrics, m0: GUIMetrics) =
  m.minW = m0.minW
  m.minH = m0.minH
  # Maximun Dimensions
  m.maxW = m0.maxW
  m.maxH = m0.maxH

proc minfit*(m: var GUIMetrics, w, h: int32) =
  # Ajust Relative
  m.minW = int16 w
  m.minH = int16 h
  m.w = m.minW
  m.h = m.minH

proc fit*(m: var GUIMetrics, m0: GUIMetrics) =
  m.w = m0.w
  m.h = m0.h
  # Zero Position
  m.x = 0
  m.y = 0

proc inset*(m: var GUIMetrics, border: int16) =
  m.x += border
  m.y += border
  # Inset Dimensions
  m.w -= border shl 1
  m.h -= border shl 1

proc clip*(m: var GUIMetrics, m0: GUIMetrics) =
  m.w += m.x
  m.h += m.y
  # Clip Metrics Region
  m.x = max(m.x, m0.x)
  m.y = max(m.y, m0.y)
  m.w = min(m.w, m0.x + m0.w) - m.x
  m.h = min(m.h, m0.y + m0.h) - m.y

proc swep*(m: var GUIMetrics, w, h: int16) =
  m.x -= max(m.x + m.w - w, 0)
  m.y -= max(m.y + m.h - h, 0)
  m.x = max(m.x, 0)
  m.y = max(m.y, 0)

# -------------------
# Math Metrics Helper
# -------------------

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
proc guiProjection*(mat: ptr array[16, float32], w, h: float32) {.importc: "gui_mat4".}
