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
import nogui/ux/layouts/[box, misc]

widget UXCallstack:
  callback cbPostpone0:
    echo "!! postpone0"
    send(self.cbFirst0)

  callback cbPostpone1:
    echo "!! postpone1"

  callback cbFirst00:
    echo "-- -- first00 call"

  callback cbFirst0:
    echo "-- first0 call"
    send(self.cbFirst00)

  callback cbFirst1:
    echo "-- first1 call"

  callback cbFirst2:
    echo "-- first2 call"

  callback cbFirst:
    echo "first call"
    send(self.cbFirst0)
    send(self.cbFirst1)
    send(self.cbFirst2)

  callback cbSecond:
    echo "second call"

  callback cbTimeout:
    echo "called very later"
    send(self.cbFirst)
    send(self.cbSecond)
    timeout(self.cbTimeout, 2000)

  callback cbInit:
    # Executes After Events
    relax(self.cbPostpone0)
    relax(self.cbPostpone0)
    relax(self.cbPostpone1)
    # Executes After Current Event
    send(self.cbFirst)
    send(self.cbSecond)
    # Executes After established Milliseconds
    #timeout(self.cbTimeout, 2000)

  new callstack():
    result.flags = {wMouse, wKeyboard}
  
  method event(state: ptr GUIState) =
    if self.test(wGrab):
      echo "() event call"
      send(self.cbInit)

controller CONLayout:
  attributes:
    widget: GUIWidget

  callback cbHello:
    echo "hello world"

  proc createWidget: GUIWidget =
    let cbHello = self.cbHello
    # Create Layout
    margin: horizontal().child:
      min: button("Minimun Left", cbHello)
      # Sub Layout
      vertical().child:
        min: button("Minimun Top", cbHello)
        callstack()
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
  createApp(1024, 600)
  let test = conlayout()
  # Clear Color
  # Open Window
  executeApp(test.widget):
    glClearColor(0.1019607843137255, 0.11196078431372549, 0.11196078431372549, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()