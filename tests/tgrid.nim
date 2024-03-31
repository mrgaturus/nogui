from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, child
import nogui/ux/prelude
# Import All Widgets
import nogui/ux/widgets/[button, label, textbox, radio, check]
import nogui/ux/layouts/[grid, box, misc, level]
import nogui/utf8
import nogui/pack

icons "tatlas", 24:
  brush := "brush.svg"
  clear := "clear.svg"
  reset := "reset.svg"
  close := "close.svg"
  color := "color.png"
  right := "right.svg"
  left := "left.svg"

controller CONLayout:
  attributes:
    widget: GUIWidget
    [text, subtext]: UTF8Input
    a: @ int32
    b: @ bool

  callback cbHello:
    echo "hello world"

  proc createWidget: UXGridLayout =
    let option = addr self.a
    let cbHello = self.cbHello
    result = grid(3, 3)
    # Adjust Layout
    result.activeMinX(0)
    result.activeMinY(0)
    result.activeMinX(2)
    result.activeMinY(2)
    # Create Layout
    return result.child:
      cell(0, 0): label("Name", hoLeft, veTop)
      cell(1, 0): textbox(addr self.text)

      cell(0, 1): label("Message", hoLeft, veTop)
      cell(1, 1): textbox(addr self.subtext)
      cell(2, 1): vlevel().child:
        min: button(iconBrush, option, 0)
        min: button(iconReset, option, 1)
        min: button(iconClear, option, 2)
        min: button(iconColor, option, 3)
        min: button(iconClose, option, 4)
        min: button(iconClose, addr self.b)
      
      cell(1, 2): horizontal().child:
        button(iconLeft, "Previous", cbHello)
        button(iconRight, "Next", cbHello)

  new conlayout():
    # Create New Widget
    result.widget = margin: result.createWidget()

proc main() =
  createApp(1024, 600)
  let test = conlayout()
  # Clear Color
  # Open Window
  executeApp(test.widget):
    glClearColor(0.09019607843137255, 0.10196078431372549, 0.10196078431372549, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()