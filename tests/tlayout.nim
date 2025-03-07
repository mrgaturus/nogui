from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, child
import nogui/ux/prelude
import nogui/ux/pivot
# Import All Widgets
import nogui/ux/layouts/[box, misc]
import nogui/ux/widgets/[button, check, radio]
import nogui/ux/separator
from nogui/pack import icons

widget UXFocusTest:
  attributes:
    pivot: GUIStatePivot

  new focustest():
    result.flags = {wMouse, wKeyboard}
  
  method event(state: ptr GUIState) =
    self.pivot.capture(state)
    if state.kind == evCursorRelease and self.test(wHover):
      self.send(wsFocus)
    echo "dist: ", self.pivot.dist
    echo "away: ", self.pivot.away

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
    case reason
    of inFocus: echo "focused: ", cast[pointer](self).repr
    of outFocus: echo "unfocused: ", cast[pointer](self).repr
    else: discard

icons "tatlas", 16:
  brush := "reset.svg"

controller CONLayout:
  attributes:
    widget: GUIWidget
    [check0, check1]: @ bool
    option: @ int32

  callback cbHello:
    echo "hello world"

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
        horizontal().child:
          focustest()
          min: vertical().child:
            button("Check 0", iconBrush, self.check0)
            button("Check 1", iconBrush, self.check1)
            min: separator()
            button("Option A", iconBrush, self.option, 0)
            button("Option B", iconBrush, self.option, 1)
            min: separator()
            button("Hello World", iconBrush, self.cbHello).glass()
          focustest()
      min: focustest()

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