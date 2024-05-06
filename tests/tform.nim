from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, child
import nogui/ux/prelude
# Import All Widgets
import nogui/ux/containers/scroll as scroll0
import nogui/ux/widgets/[button, slider, check, radio, label, scroll]
import nogui/ux/layouts/[form, level, misc]
import nogui/ux/values/[linear, dual, scroller]
import nogui/format
from math import pow

# ---------------------
# Preferred Size Widget
# ---------------------

widget UXLayoutPreferred:
  attributes:
    [w, h]: int16

  new preferred(widget: GUIWidget, w, h: int32):
    result.kind = wkLayout
    result.add(widget)
    # Preferred Min Size
    result.w = int16 w
    result.h = int16 h
  
  method update =
    self.metrics.minW = self.w
    self.metrics.minH = self.h
  
  method layout =
    let m1 = addr self.first.metrics
    m1[].fit(self.metrics)

# -------------
# Field Helpers
# -------------

proc field(name: string, check: & bool, w: GUIWidget): GUIWidget =
  let ck = # Dummy Test
    if not isNil(check): check
    else: cast[& bool](w)
  # Create Middle Checkbox
  let c = checkbox("", ck)
  if isNil(check):
    c.flags = {wHidden}
  # Level Widget
  let l = level().child:
    label(name, hoLeft, veMiddle)
    tail(): c
  # Return Widget
  field(l): w

proc spacing(w: GUIWidget): GUIWidget =
  let a = adjust(w)
  # Adjust Metrics
  a.hoAlign = hoMiddle
  a.veAlign = veTop
  a.scaleW = 0.75
  a.forceH = low int16
  #result.margin = 4
  result = margin(size = 16, a)

proc half(value: & Linear): UXAdjustLayout =
  result = adjust slider(value)
  # Adjust Metrics
  result.scaleW = 0.75

controller CONLayout:
  attributes:
    widget: GUIWidget
    [valueA, valueB]: @ Linear
    [valueA1, valueB1]: @ Linear
    [valueC, valueD]: @ Linear
    [valueE, valueF]: @ Linear
    [valueG, valueH]: @ Linear
    [check0, check1]: @ bool
    [check2, check3]: @ bool
    [check4, check5]: @ bool
    scroll: @ Scroller
    dual0: @ LinearDual
    a: @ int32

  callback cbHello:
    echo "hello world"

  proc createWidget: GUIWidget =
    let cbHello = self.cbHello
    # Create Widget Layout
    let widget = spacing: form().child:
      field("Size"): slider(self.valueA)
      field("Min Size"): half(self.valueA1)
      field("Opacity"): slider(self.valueB)
      field("Min Opacity"): half(self.valueB1)
      
      button("lol equisde gggg", cbHello)
      label("", hoLeft, veMiddle)

      field(): button("Value A", self.a, 10)
      field(): button("Value B", self.a, 20)
      field(): checkbox("Transparent", self.check0)

      field("Blending", self.check2): 
        slider0int(self.valueC) do (s: ShallowString, v: Linear):
          let i = v.toInt
          s.format("%d + %d = %d", i, i, i + i)
      field("Dilution", self.check3): 
        slider0int(self.valueD, fmt"%d cosos")
      field("Persistence", nil): 
        slider(self.valueF)
      field("Watering", self.check4): 
        slider(self.valueE)
      field(): checkbox("Colouring", self.check1)
      
      label("", hoLeft, veMiddle)
      field("Min Pressure"): slider(self.valueG)
      field("Curve Pressure"): dual0float(self.dual0) do (s: ShallowString, v: LinearDual):
        let 
          f = v.toFloat
          fs = pow(2.0, f) * 100.0
        if f >= 0:
          let i = int32(fs)
          s.format("%d%%", i)
        else: s.format("%.1f%%", fs)
      # Scroller Example
      label("", hoLeft, veMiddle)
      field("Scroller"): scrollbar(self.scroll, false)
    # Create Scroll Layout
    result = scrollview:
      preferred(widget, 600, 400)


  new conlayout():
    # Create New Widget
    result.valueA = linear(0, 100)
    result.valueA1 = linear(0, 100)
    result.valueB1 = linear(0, 100)
    result.valueB = linear(20, 50)
    result.valueC = linear(-100, 100)
    result.valueD = linear(0, 5)
    result.valueE = linear(0, 100)
    result.valueF = linear(0, 200)
    result.scroll = scroller(1000, 250)
    result.valueG = value(result.valueD.peek, result.cbHello)
    result.dual0 = dual(-5, 5)
    result.widget = result.createWidget()
    result.dual0.peek[].lorp(-4)

proc main() =
  createApp(1024, 600)
  let test = conlayout()
  # Clear Color
  # Open Window
  executeApp(test.widget):
    glClearColor(0.1019607843137255, 0.11196078431372549, 0.11196078431372549, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()