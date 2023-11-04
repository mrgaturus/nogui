from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, child
import nogui/ux/prelude
# Import All Widgets
import nogui/ux/widgets/[button, slider, check, radio, label]
import nogui/ux/layouts/[form, level, misc]
import nogui/values
import nogui/format

proc field(name: string, check: & bool, w: GUIWidget): GUIWidget =
  let ck = # Dummy Test
    if not isNil(check): check
    else: cast[& bool](w)
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

proc half(value: & Lerp): UXAdjustLayout =
  result = adjust slider(value)
  # Adjust Metrics
  result.scaleW = 0.75

controller CONLayout:
  attributes:
    widget: GUIWidget
    [valueA, valueB]: @ Lerp
    [valueA1, valueB1]: @ Lerp
    [valueC, valueD]: @ Lerp
    [valueE, valueF]: @ Lerp
    [valueG, valueH]: @ Lerp
    [check0, check1]: @ bool
    [check2, check3]: @ bool
    [check4, check5]: @ bool
    a: @ int32

  callback cbHello:
    echo "hello world"

  proc createWidget: GUIWidget =
    let cbHello = self.cbHello
    # Create Layout
    spacing: form().child:
      field("Size"): slider(self.valueA)
      field("Min Size"): half(self.valueA1)
      field("Opacity"): slider(self.valueB)
      field("Min Opacity"): half(self.valueB1)
      
      button("lol equisde", cbHello)
      label("", hoLeft, veMiddle)

      field(): button("Value A", self.a, 10)
      field(): button("Value B", self.a, 20)
      field(): checkbox("Transparent", self.check0)

      field("Blending", self.check2): 
        slider0int(self.valueC) do (s: ShallowString, v: Lerp):
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

  new conlayout():
    # Create New Widget
    result.valueA = lerp(0, 100).value
    result.valueA1 = lerp(0, 100).value
    result.valueB1 = lerp(0, 100).value
    result.valueB = lerp(20, 50).value
    result.valueC = lerp(-100, 100).value
    result.valueD = lerp(0, 5).value
    result.valueE = lerp(0, 100).value
    result.valueF = lerp(0, 200).value
    result.valueG = value(result.valueD.peek, result.cbHello)
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