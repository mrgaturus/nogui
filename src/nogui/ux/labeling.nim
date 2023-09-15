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
  GUILabelPosition* = object
    # i -> Icon
    # t -> Text
    xi*, yi*: int16
    xt*, yt*: int16

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
