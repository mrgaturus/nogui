import prelude except 
  widget,
  event,
  signal,
  pushTimer,
  stopTimer

# --------------------
# Icon Existence Check
# --------------------

const CTXIconEmpty* = CTXIconID(65535)
# XXX: is posible have 65535 icons?
template noEmpty*(id: CTXIconID): bool =
  cast[uint16](id) < 65535

# --------------------------
# Icon/Text Labeling Metrics
# --------------------------

type
  GUILabelMetrics* = object
    w*, h*: int16
    # Width Advance Metrics
    icon*, label*: int16
  GUIMenuMetrics* {.borrow.} = 
    distinct GUILabelMetrics
  # Label Positioning
  GUILabelPosition* = object
    xi*, yi*: int16 # i -> Icon
    xt*, yt*: int16 # t -> Text

# --------------------------
# Icon/Text Metric Preparing
# --------------------------

proc metricsLabel*(label: string, icon = CTXIconEmpty): GUILabelMetrics =
  let 
    app = getApp()
    font = addr app.font
    adv = font.asc shr 1
    # Text Size
    wt = int16 width(label)
  # Store Label Metrics
  result.w = wt
  result.h = font.height
  result.label = wt
  # Store Icon Width
  if icon.noEmpty:
    let g = icon(app.atlas, uint16 icon)
    # Store Icon Metrics
    result.w += g.w
    result.h = max(result.h, g.h)
    result.icon = g.w
  # Add Advance Padding
  if result.label > 0 and result.icon > 0:
    result.w += adv

proc metricsOption*(label: string): GUILabelMetrics =
  let 
    app = getApp()
    font = addr app.font
    adv = app.font.asc shr 1
    # Labeling Metrics
    wt = int16 width(label)
    wi = font.height
  # Store Label Width
  result.w = wi + adv + wt
  if wt <= 0 or wi <= 0: 
    result.w -= adv
  # Store Label Height
  result.h = wi
  # Store Width Advance
  result.icon = wi
  result.label = wt

# ---------------------
# Icon/Text Positioning
# ---------------------

proc locate*(m: GUILabelMetrics, r: GUIRect): GUILabelPosition =
  let
    cx = int16 r.x
    cy = int16 r.y
    # Text Positions
    font = addr getApp().font
    xt = m.w - m.label
    # Vertical Positions
    yt = (m.h - font.height + font.baseline) shr 1
    yi = (m.h - m.icon) shr 1
  # Icon Position
  result.xi = cx
  result.yi = cy + yi
  # Text Position
  result.xt = cx + xt
  result.yt = cy + yt

proc center*(m: GUILabelMetrics, r: GUIRect): GUILabelPosition =
  let
    cx = int16 (r.w - m.w) shr 1
    cy = int16 (r.h - m.h) shr 1
  # Calculate Initial Location 
  result = locate(m, r)
  # Move to Center
  result.xi += cx
  result.yi += cy
  # Text Position
  result.xt += cx
  result.yt += cy

proc left*(m: GUILabelMetrics, r: GUIRect): GUILabelPosition =
  let cy = int16 (r.h - m.h) shr 1
  # Calculate Initial Location 
  result = locate(m, r)
  # Move to Center
  result.yi += cy
  result.yt += cy

# -----------------------
# Icon/Label Menu Metrics
# -----------------------

proc metricsMenu*(label: string, icon = CTXIconEmpty): GUIMenuMetrics =
  var lm = # Calculate Initial Metrics
    if icon.noEmpty():
      metricsLabel(label, icon)
    else: metricsOption(label)
  # Return GUIMenuMetrics
  GUIMenuMetrics(lm)

proc width*(m: GUIMenuMetrics): int16 =
  let adv = getApp().font.asc shr 1
  # Calculate Menu Full Size
  m.w + adv + m.icon

proc label*(m: GUIMenuMetrics, r: GUIRect): GUILabelPosition =
  # Calculate Label Location
  result = GUILabelMetrics(m).left(r)
  # Add Label Padding
  let adv = getApp().font.asc shr 1
  result.xt += adv
  result.xi += adv

proc extra*(m: GUIMenuMetrics, r: GUIRect): GUIRect =
  let
    size = m.icon
    cx = r.x + (r.w - size)
    cy = r.y + (r.h - m.h) shr 1
  # Calculate Extra Icon Rectangle
  result = GUIRect(x: cx, y: cy, w: size, h: size)
  result.x -= getApp().font.asc shr 1

# -----------------------
# Triangle Icon Rendering
# -----------------------

proc arrowRect(r: GUIRect, sw, sh: float32): CTXRect =
  result = rect(r)
  # Calculate Center
  let 
    cx = (result.x + result.xw) * 0.5
    cy = (result.y + result.yh) * 0.5
  # Scale Center
  result.x = (result.x - cx) * sw + cx
  result.y = (result.y - cy) * sh + cy
  result.xw = (result.xw - cx) * sw + cx
  result.yh = (result.yh - cy) * sh + cy

proc arrowRight*(ctx: ptr CTXRender, r: GUIRect) =
  let
    r = arrowRect(r, 0.25, 0.5)
    c = (r.y + r.yh) * 0.5
    # Triangle Points
    p0 = point(r.x, r.y)
    p1 = point(r.x, r.yh)
    p2 = point(r.xw, c)
  # Render Triangle
  ctx.triangle(p0, p1, p2)

proc arrowDown*(ctx: ptr CTXRender, r: GUIRect) =
  let
    r = arrowRect(r, 0.5, 0.25)
    c = (r.x + r.xw) * 0.5
    # Triangle Points
    p0 = point(r.xw, r.y)
    p1 = point(r.x, r.y)
    p2 = point(c, r.yh)
  # Render Triangle
  ctx.triangle(p0, p1, p2)
