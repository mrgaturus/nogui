from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/ux/layouts/base import dummy
import nogui/ux/prelude
import nogui/builder
# Import Docks Containers
import nogui/ux/containers/dock/[panel, session, base]

# -------------
# Helper Widget
# -------------

widget UXDockBodyTest:
  attributes:
    color: CTXColor

  new dockbodytest(color: CTXColor, w, h: int16):
    result.color = color
    # Set Minimun Size
    result.metrics.minW = w
    result.metrics.minH = h

  method draw(ctx: ptr CTXRender) =
    ctx.color self.color
    ctx.fill(rect self.rect)

proc dockpanel0test(x, y: int16): UXDockPanel =
  result = dockpanel()
  # Locate Panel
  let m0 = addr result.metrics
  m0.x = x; m0.y = y

# ---------------
# Main Controller
# ---------------

controller CXDockTesting:
  attributes:
    root: GUIWidget
    widget: UXDockSession

  proc createWidget: UXDockSession =
    self.root = dummy()
    # Create Some Panels
    let
      panel0 = dockpanel0test(280, 20)
      panel1 = dockpanel0test(170, 150)
      panel2 = dockpanel0test(300, 200)
    # Create Some Tabs
    panel0.add dockcontent("Tab 1", dockbodytest(0x00FFFFFF'u32, 210, 120))
    panel0.add dockcontent("Tab 2", dockbodytest(0x7F00FF00'u32, 210, 120))
    panel0.add dockcontent("Tab 3", dockbodytest(0x7FFFFF00'u32, 210, 120))
    # Create Some Tabs 2
    panel1.add dockcontent("Tab 1", dockbodytest(0xFFFFFFFF'u32, 150, 250))
    panel1.add dockcontent("T", dockbodytest(0x0000FF00'u32, 250, 100))
    # Create Unique Tab
    panel2.add dockcontent("My Tool", dockbodytest(0x0000FF00'u32, 250, 200))
    # Create Dock Session
    result = docksession(self.root).child:
      panel0
      panel1
      panel2

  new docktesting():
    result.widget = result.createWidget()

# -------------
# Main GUI Proc
# -------------

proc main() =
  createApp(1024, 600)
  let test = docktesting()
  # Open Window
  executeApp(test.widget):
    glClearColor(0.75, 0.75, 0.75, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()