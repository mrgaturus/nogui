import prelude

# -----------------------
# Simple Separator Widget
# -----------------------

widget UXSeparatorH:
  new separator():
    let
      metrics = addr getApp().font
      fontsize = metrics.size
      # Minimun Separator Size
      height = (metrics.height + fontsize) shr 1
    result.minimum(height, height)

  method draw(ctx: ptr CTXRender) =
    ctx.color getApp().colors.item and 0x7FFFFFFF
    var r = rect(self.rect)
    # Locate Separator Line
    r.y0 = (r.y0 + r.y1) * 0.5 - 1
    r.y1 = r.y0 + 2
    # Create Simple Line
    ctx.fill(r)

widget UXSeparatorV:
  new vseparator():
    let
      metrics = addr getApp().font
      fontsize = metrics.size
      # Minimun Separator Size
      height = (metrics.height + fontsize) shr 1
    result.minimum(height, height)

  method draw(ctx: ptr CTXRender) =
    ctx.color getApp().colors.item and 0x7FFFFFFF
    var r = rect(self.rect)
    # Locate Separator Line
    r.x0 = (r.x0 + r.x1) * 0.5 - 1
    r.x1 = r.x0 + 2
    # Create Simple Line
    ctx.fill(r)
