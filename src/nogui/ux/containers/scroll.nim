import ../prelude
# Import Scroll Widget
import ../widgets/scroll
import ../values/scroller

# ---------------------
# Scroll View Container
# ---------------------

widget UXScrollOffset:
  attributes:
    {.cursor.}:
      widget: GUIWidget
    # Scroll Attributes
    {.public.}:
      [ox, oy]: @ Scroller
      # Scroll Directions
      horizontal: bool
      vertical: bool

  callback cbOffset:
    self.send(wsLayout)

  new scrolloffset(widget: GUIWidget):
    result.kind = wkContainer
    # Add Offset Widget
    result.widget = widget
    result.add(widget)
    # Define Offset Callbacks
    result.ox.cb(result.cbOffset)
    result.oy.cb(result.cbOffset)

  method update =
    let
      m0 = addr self.metrics
      m1 = addr self.widget.metrics
    # Reset Min Size
    m0.minW = 0
    m0.minH = 0
    # Copy Min Size
    if not self.horizontal:
      m0.minW = m1.minW
    if not self.vertical:
      m0.minH = m1.minH

  method layout =
    let
      m0 = addr self.metrics
      m1 = addr self.widget.metrics
    # Reset Offset
    m1.x = 0
    m1.y = 0
    m1.w = m0.w
    m1.h = m0.h
    # Vertical Offset
    if self.vertical:
      let oy = (addr self.oy).peek()
      # Scroller Vertical Metric
      oy[].width(float32 m1.minH)
      oy[].view(float32 m0.h)
      # Layout Vertical Metric
      m1.y -= int16 oy[].position
      m1.h = m1.minH
    # Horizontal Offset
    if self.horizontal:
      let ox = (addr self.ox).peek()
      # Scroller Horizontal Metric
      ox[].width(float32 m1.minW)
      ox[].view(float32 m0.w)
      # Layout Horizontal Metric
      m1.x -= int16 ox[].position
      m1.w = m1.minW

# ----------------------
# Scroll View Forwarding
# ----------------------

widget UXScrollView:
  attributes:
    # Scroll Widgets
    {.cursor.}:
      [barV, barH]: UXScroll
      target: UXScrollOffset

  proc `horizontal=`*(h: bool) {.inline.} =
    self.target.horizontal = h

  proc `vertical=`*(v: bool) {.inline.} =
    self.target.vertical = v

  new scrollview(widget: GUIWidget):
    result.kind = wkForward
    result.flags = {wMouse}
    # Create Scroll Widgets
    let
      target = scrolloffset(widget)
      barV = scrollbar(target.oy, true)
      barH = scrollbar(target.ox, false)
    # Define Scroll Widgets
    result.target = target
    result.barV = barV
    result.barH = barH
    # Vertical Scroll by Default
    target.vertical = true
    # Layout Scroll Widgets
    result.add target
    result.add barV
    result.add barH

  method update =
    let
      target {.cursor.} = self.target
      # Scrollview Metrics
      m0 = addr self.metrics
      m1 = addr target.metrics
      border = getApp().font.asc shr 2
    # Copy Min Size
    m0.minW = m1.minW
    m0.minH = m1.minH
    # Append Scrollbar Size
    if target.vertical:
      let m2 = addr self.barV.metrics
      m0.minW += border + m2.minH
    if target.horizontal:
      let m2 = addr self.barH.metrics
      m0.minW += border + m2.minW

  method layout =
    let
      target {.cursor.} = self.target
      barV {.cursor.} = self.barV
      barH {.cursor.} = self.barH
      # Widget Metrics
      m0 = addr self.metrics
      m1 = addr target.metrics
      m2 = addr target.widget.metrics
      # Scrollbar Checks
      vertical = target.vertical
      horizontal = target.horizontal
      # Scrollbar Border Metric
      border = getApp().font.asc shr 2
    # Layout Target Metrics
    m1.x = 0
    m1.y = 0
    m1.w = m0.w
    m1.h = m0.h
    # Hide Scrollbars
    barV.flags.incl(wHidden)
    barH.flags.incl(wHidden)
    # Prepare Scrollbars
    var
      w0 = m1.w
      h0 = m1.h
    if vertical and m2.minH > h0:
      w0 -= barV.metrics.minW + border
    if horizontal and m2.minW > w0:
      h0 -= barH.metrics.minH + border
    # Vertical Scrollbar
    if vertical and m2.minH > h0:
      let m = addr barV.metrics
      m.x = m0.w - m.minW
      m.w = m.minW
      m.h = m0.h
      # Remove Hidden
      barV.flags.excl(wHidden)
      m1.w -= m.w + border
    # Horizontal Scrollbar
    if horizontal and m2.minW > w0:
      let m = addr barH.metrics
      m.y = m0.h - m.minH
      m.h = m.minH
      m.w = m0.w
      # Remove Hidden
      barH.flags.excl(wHidden)
      m1.h -= m.h + border
    # Adjust Scrollbar Intersection
    if wHidden notin (barV.flags + barH.flags):
      let
        mV = addr barV.metrics
        mH = addr barH.metrics
      mV.h -= mH.minH
      mH.w -= mV.minW
