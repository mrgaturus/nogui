import nogui/core/shortcut
from nogui/libs/gl import 
  glClear,
  glClearColor,
  GL_COLOR_BUFFER_BIT,
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp, class
from nogui/builder import controller, child
import nogui/ux/prelude
# Import All Widgets
import nogui/ux/layouts/[box, misc]
import nogui/ux/widgets/color
import nogui/ux/values/chroma
import nogui/pack

cursors 64:
  pepper := "pepper.png" (200, 200)

widget UXForwardTest:
  new forwardtest(w: GUIWidget):
    result.kind = wkWidget
    result.flags = {wMouse}
    # Add Child Widget
    result.add w
  
  method update =
    self.metrics.minW = self.first.metrics.minW
    self.metrics.minH = self.first.metrics.minH

  method layout =
    let
      m0 = addr self.metrics
      m1 = addr self.first.metrics
    m1.x = 0
    m1.y = 0
    m1.w = m0.w
    m1.h = m0.h

  method event(state: ptr GUIState) =
    #echo "Forward: ", state.mx, " ", state.my
    if not self.test(wGrab):
      send(self.first, wsForward)

  method handle(reason: GUIHandle) =
    echo cast[pointer](self).repr, " ", reason

widget UXFocusTest:
  attributes:
    shape: GUICursorSys

  new focustest():
    result.flags = {wMouse, wKeyboard}
  
  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      if Mod_Shift in state.mods:
        self.send(wsHold)
      if Mod_Control in state.mods:
        getWindow().send(wsUnHold)
      if self.test(wHover):
        self.send(wsFocus)
    #echo "-- Widget: ", state.mx, " ", state.my
    if state.kind == evKeyDown:
      echo name(state.key)
      self.shape = cast[GUICursorSys]((ord(self.shape) + 1) mod (1 + ord high GUICursorSys))
      if self.test(wHover):
        getWindow().cursor(self.shape)
      echo self.shape

  method update =
    let m = addr self.metrics
    m.minW = width("DEMO FOCUS").int16
    m.minH = width("DEMO").int16

  method draw(ctx: ptr CTXRender) =
    ctx.color self.itemColor()
    # Draw Focused if not Hovered
    if self.flags * {wFocus, wHover, wGrab} == {wFocus}:
      ctx.color getApp().colors.text
    # Draw Focus Check
    ctx.fill rect(self.rect)

  method handle(reason: GUIHandle) =
    echo "-- ", cast[pointer](self).repr, " ", reason
    let win = getWindow()
    case reason
    of inHover: win.cursor(cursorPepper)
    of outHover: win.cursorReset()
    else: discard

controller CONLayout:
  attributes:
    widget: GUIWidget
    color: @ HSVColor

  callback cbHello:
    echo "hello world"

  callback cbShortcut:
    echo "hello shortcut"

  callback cbObserveCursor:
    let state = getApp().state
    echo "observer", state.mx, " ", state.my

  proc createWidget: GUIWidget =
    # Create Layout
    margin(16): horizontal().child:
      min: focustest()
      # Sub Layout
      vertical().child:
        min: focustest()
        focustest()
        min: focustest()
        # Sub Sub Layout
        forwardtest:
          horizontal().child:
            forwardtest:
              vertical().child:
                focustest()
                focustest()
                focustest()
            colorwheel(self.color)
            colorwheel0triangle(self.color)
      min: focustest()

  new conlayout():
    # Register Shortcuts
    let
      shorts = getWindow().shorts
      observers = getWindow().observers
    shorts[].register:
      let s0 = shortcut(result.cbHello, NK_A + {Mod_Control, Mod_Shift})
      s0.mode = shortHold; s0
    shorts[].register shortcut(result.cbShortcut, NK_A + {Mod_Control})
    # Register Observer
    observers[].register observer(result.cbObserveCursor, {evCursorMove})
    # Create New Widget
    result.widget = result.createWidget()

proc main() =
  createApp(1024, 600)
  # Define Title Properties
  getApp().class("nogui", "nogui")
  getWindow().title("Forward Testing")

  let test = conlayout()
  # Clear Color
  executeApp(test.widget):
    glClearColor(0.1019607843137255, 0.11196078431372549, 0.11196078431372549, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()
