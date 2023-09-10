import prelude except 
  widget,
  event,
  signal,
  pushTimer,
  stopTimer

# ------------------------
# Icon/Text Metric Helpers
# ------------------------

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

proc metrics*(icon: CTXIconID, label: string): GUILabelMetrics =
  let 
    app = getApp()
    font = addr app.font
    adv = font.asc shr 1
    # Labeling Metrics
    glyph = icon(app.atlas, uint16 icon)
    wt = int16 width(label)
    wi = glyph.w
  # Store Label Width
  result.w = wi + adv + wt
  if wt <= 0: result.w -= adv
  # Store Label Height
  result.h = max(font.height, glyph.h)
  # Store Width Advance
  result.icon = wi
  result.label = wt

proc metrics*(label: string): GUILabelMetrics =
  let 
    app = getApp()
    font = addr app.font
    adv = app.font.asc shr 1
    # Labeling Metrics
    wt = int16 width(label)
    wi = font.height
  # Store Content Metrics
  result.w = wi + adv + wt
  result.h = wi
  # Store Width Advance
  result.icon = wi
  result.label = wt

proc center*(m: GUILabelMetrics, r: GUIRect): GUILabelPosition =
  let
    cx = int16 r.x + (r.w - m.w) shr 1
    cy = int16 r.y + (r.h - m.h) shr 1
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
