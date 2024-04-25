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

proc mimic*(parent: var GUIMetrics, m: GUIMetrics) =
  parent.minW = m.minW
  parent.minH = m.minH
  # Maximun Dimensions
  parent.maxW = m.maxW
  parent.maxH = m.maxH

proc fit*(m: var GUIMetrics, parent: GUIMetrics) =
  m.w = parent.w
  m.h = parent.h
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
