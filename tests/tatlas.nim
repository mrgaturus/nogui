from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
# Import nogui stuff
import nogui/ux/prelude
from nogui/data import icons
from nogui/builder import controller
from nogui import createApp, executeApp

icons "tatlas", 16:
  brush := "brush.svg"
  clear := "clear.svg"
  reset := "reset.svg"
  close := "close.svg"
  color := "color.png"

icons "tatlas", 32:
  brush32 := "brush.svg"
  clear32 := "clear.svg"
  #reset32 := "reset.svg"
  close32 := "close.svg"
  color32 := "color.png"

# ------------------
# Atlas Debug Widget
# ------------------

widget DebugAtlas:
  attributes:
    cb: GUICallback

  new debugatlas(cb: GUICallback):
    result.flags = wMouse
    result.cb = cb

  method draw(ctx: ptr CTXRender) =
    let 
      (texID, w, h) = getApp().atlas.info
      metrics = addr self.metrics
      x = metrics.x
      y = metrics.y
      rect = rect(x, y, w, h)
    # Fill Black Background
    ctx.color 0xFF000000'u32
    ctx.fill(rect)
    # White Color
    ctx.color 0xFFFFFFFF'u32
    ctx.texture(rect, texID)
    # Write some text and icons
    ctx.text(x + w div 2, y + h + 8, "Hello World Nim")
    ctx.icon(x + w div 2, y + h + 32, iconBrush)
    ctx.icon(x + w div 2 + 32, y + h + 32, iconClear32)

  method event(state: ptr GUIState) =
    case state.kind
    of evCursorRelease:
      self.cb.push()
    else: discard

# ------------------
# Controller Testing
# ------------------

controller TestController:
  attributes:
    [a, b]: int
    widget: DebugAtlas

  # Hello World Callback
  callback helloworld:
    echo "hello world ", self.a, " ", self.b

  # Controller Constructor
  new testcontroller(a, b: int):
    result.a = a
    result.b = b
    # Bind Current Callback
    let w = debugatlas(result.helloworld)
    result.widget = w

# -------------------
# Main Widget Testing
# -------------------

proc main() =
  createApp(1024, 600, nil)
  let test = testcontroller(10, 20)
  # Open Window
  executeApp(test.widget):
    glClearColor(0.5, 0.5, 0.5, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  
when isMainModule:
  main()
