from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, child
import nogui/ux/prelude
# Import All Widgets
import nogui/ux/widgets/[button, slider, check, label]
import nogui/ux/layouts/[form, level, misc]
import nogui/values

proc field(name: string, check: ptr bool, w: GUIWidget): GUIWidget =
  let ck = # Dummy Test
    if not isNil(check): check
    else: cast[ptr bool](w)
  # Create Middle Checkbox
  let c = checkbox("", ck)
  if isNil(check):
    c.flags = wHidden
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

proc half(value: ptr Value): UXAdjustLayout =
  result = adjust slider(value)
  # Adjust Metrics
  result.scaleW = 0.75

controller CONLayout:
  attributes:
    widget: GUIWidget
    [valueA, valueB]: Value
    [valueA1, valueB1]: Value
    [valueC, valueD]: Value
    [valueE, valueF]: Value
    [valueG, valueH]: Value
    [check0, check1]: bool
    [check2, check3]: bool
    [check4, check5]: bool

  callback cbHello:
    echo "hello world"

  proc createWidget: GUIWidget =
    let cbHello = self.cbHello
    # Create Layout
    spacing: form().child:
      field("Size"): slider(addr self.valueA)
      field("Min Size"): half(addr self.valueA1)
      field("Opacity"): slider(addr self.valueB)
      field("Min Opacity"): half(addr self.valueB1)
      
      button("lol equisde", cbHello)
      label("", hoLeft, veMiddle)

      field(): checkbox("Transparent", addr self.check0)
      field("Blending", addr self.check2): 
        slider(addr self.valueC)
      field("Dilution", addr self.check3): 
        slider(addr self.valueD)
      field("Persistence", nil): 
        slider(addr self.valueF)
      field("Watering", addr self.check4): 
        slider(addr self.valueE)
      field(): checkbox("Colouring", addr self.check1)
      
      label("", hoLeft, veMiddle)
      field("Min Pressure"): slider(addr self.valueG)

  new conlayout():
    # Create New Widget
    interval(result.valueA, 0, 100)
    interval(result.valueA1, 0, 100)
    interval(result.valueB1, 0, 100)
    interval(result.valueB, 20, 50)
    interval(result.valueC, -100, 100)
    interval(result.valueD, 0, 5)
    interval(result.valueE, 0, 100)
    interval(result.valueF, 0, 200)
    interval(result.valueG, 0, 300)
    result.widget = result.createWidget()

proc main() =
  createApp(1024, 600, nil)
  let test = conlayout()
  # Clear Color
  # Open Window
  executeApp(test.widget):
    glClearColor(0.1019607843137255, 0.11196078431372549, 0.11196078431372549, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()