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
import nogui/async/core
from os import sleep

type
  TestObject = object
    time: int32
    cb: CoroCallback

proc test0handle(coro: Coroutine[TestObject], signal: CoroSignal) =
  echo "handled signal: ", repr(cast[pointer](coro)), " ", signal

proc test0task(coro: Coroutine[TestObject]) =
  let data = coro.data
  # Sleep and Send
  for i in 0 ..< data.time:
    sleep(1); coro.pass()
  coro.send(data.cb)

# ---------------------
# Coroutine Widget Test
# ---------------------

widget UXCoroutineButton:
  attributes:
    target: ptr Coroutine[TestObject]
    cb: GUICallback

  new corobutton(target: ptr Coroutine[TestObject], cb: GUICallback):
    result.flags = {wMouse}
    result.target = target
    result.cb = cb

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      let target = self.target
      target[] = coroutine(TestObject)
      target[].setProc(test0task)
      target[].setHandle(test0handle)
      let data = target[].data
      data.time = 1000
      data.cb = self.cb
      # Spawn Coroutine
      target[].spawn()

# --------------------
# Coroutine Controller
# --------------------

controller CXCoroutineTest:
  attributes:
    coro: Coroutine[TestObject]
    widget: GUIWidget

  callback cbHello:
    echo "hello world"

  callback cbPause:
    self.coro.pause()

  callback cbResume:
    self.coro.resume()

  proc createWidget: GUIWidget =
    let cbHello = self.cbHello
    # Create Layout
    margin: horizontal().child:
      min: button("Minimun Left", cbHello)
      # Sub Layout
      vertical().child:
        min: button("Minimun Top", cbHello)
        corobutton(addr self.coro, self.cbHello)
        min: horizontal().child:
          button("Pause Coroutine", self.cbPause)
          button("Resume Coroutine", self.cbResume)
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
