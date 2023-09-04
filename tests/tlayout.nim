from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, child
import nogui/ux/prelude
# Import All Widgets
import nogui/ux/widgets/button
import nogui/ux/layouts/box

controller CONLayout:
  attributes:
    widget: GUIWidget

  callback cbHello:
    echo "hello world"

  proc createWidget: GUIWidget =
    let cbHello = self.cbHello
    # Create Layout
    horizontal().child:
      min: button("Minimun Left", cbHello)
      # Sub Layout
      vertical().child:
        min: button("Minimun Top", cbHello)
        button("Growable Center", cbHello)
        min: button("Minimun Bottom", cbHello)
        # Sub Sub Layout
        horizontal().child:
          button("Sub Sub Left", cbHello)
          min: button("Minimun Center", cbHello)
          button("Sub Sub Right", cbHello)
      min: button("Minimun Right", cbHello)

  new conlayout():
    # Create New Widget
    result.widget = result.createWidget()

proc main() =
  createApp(1024, 600, nil)
  let test = conlayout()
  # Clear Color
  # Open Window
  executeApp(test.widget):
    glClearColor(0.5, 0.5, 0.5, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()