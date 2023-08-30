from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, child
import nogui/ux/prelude
# Import All Widgets
import nogui/ux/widgets/[slider, check, label]
import nogui/ux/layouts/form
import nogui/values

controller CONLayout:
  attributes:
    widget: GUIWidget
    [valueA, valueB]: Value
    [valueC, valueD]: Value
    [check0, check1]: bool

  callback cbHello:
    echo "hello world"

  proc createWidget: GUIWidget =
    # Create Layout
    form().child:
      field(): checkbox("Antialising", addr self.check0)
      field("Size"): slider(addr self.valueA)
      field("Opacity"): slider(addr self.valueB)
      field(): checkbox("Auto Flow", addr self.check1)
      
      label("", hoLeft, veMiddle)
      label("Color Mixing", hoLeft, veMiddle)
      field("Blending"): slider(addr self.valueC)
      field("Dilution"): slider(addr self.valueD)

  new conlayout():
    # Create New Widget
    interval(result.valueA, 0, 100)
    interval(result.valueB, 20, 50)
    interval(result.valueC, -100, 100)
    interval(result.valueD, 0, 5)
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