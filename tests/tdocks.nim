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
import nogui/ux/containers/dock
import nogui/ux/widgets/menu

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

  proc createRow0(x, y: int16): UXDockRow =
    result = dockrow()
    let
      panel0 = dockpanel()
      panel1 = dockpanel()
      panel2 = dockpanel()
    # Register Content
    panel0.add dockcontent("Panel 1", dockbodytest(0x00FFFFFF'u32, 210, 120))
    panel1.add dockcontent("Panel 2", dockbodytest(0x00FFFFFF'u32, 300, 230))
    panel2.add dockcontent("Panel 3", dockbodytest(0x00FFFFFF'u32, 100, 80))
    # Register Panels to Row
    result = dockrow().child:
      panel0
      panel1
      panel2
    # Locate Panel Position
    result.metrics.x = x
    result.metrics.y = x

  proc createRow1(x, y: int16): UXDockRow =
    result = dockrow()
    let
      panel0 = dockpanel()
      panel1 = dockpanel()
    # Register Content
    panel0.add dockcontent("Panel 1", dockbodytest(0x00FFFFFF'u32, 100, 200))
    panel1.add dockcontent("Panel 2", dockbodytest(0x00FFFFFF'u32, 210, 100))
    # Register Panels to Row
    result = dockrow().child:
      panel0
      panel1
    # Locate Panel Position
    result.metrics.x = x
    result.metrics.y = x

  proc createGroup(x, y: int16): UXDockGroup =
    let
      row0 = self.createRow0(x, y)
      row1 = self.createRow1(x, y)
    # Register Rows to Group
    result = dockgroup: dockcolumns().child:
      row0
      row1
    # Locate Panel Position
    result.metrics.x = x
    result.metrics.y = x

  callback cbHello:
    echo "Hello World"

  proc createWidget: UXDockSession =
    self.root = dockbodytest(0x2FFFFFFF'u32, 210, 120)
    # Create Some Panels
    let
      panel0 = dockpanel0test(280, 20)
      panel1 = dockpanel0test(170, 150)
      panel2 = dockpanel0test(300, 200)
    # Create Some Tabs
    let co0 = dockcontent("Menu 1", dockbodytest(0x00FFFFFF'u32, 210, 120))
    co0.menu = menu("#tabmenu").child:
      menuitem("Hello", self.cbHello)
      menuitem("This", self.cbHello)
      menuitem("Menu", self.cbHello)
    # Create Some Tabs
    let co1 = dockcontent("Menu 2", dockbodytest(0x00FFFFFF'u32, 210, 120))
    co1.menu = menu("#tabmenu").child:
      menuitem("Another", self.cbHello)
      menuitem("Menu", self.cbHello)
      menuseparator()
      menuitem("Created", self.cbHello)
      menu("Sub Menu").child:
        menuitem("Menu 1", self.cbHello)
        menuitem("Menu 2", self.cbHello)
    panel0.add co0
    panel0.add co1
    panel0.add dockcontent("Tab 3", dockbodytest(0x7FFFFF00'u32, 210, 120))
    # Create Some Tabs 2
    panel1.add dockcontent("Tab 1", dockbodytest(0xFFFFFFFF'u32, 150, 250))
    panel1.add dockcontent("T", dockbodytest(0x0000FF00'u32, 250, 100))
    # Create Unique Tab
    panel2.add dockcontent("My Tool", dockbodytest(0x0000FF00'u32, 250, 200))
    # Create Dock Session
    result = docksession(self.root)
    discard result.docks.child:
      panel0
      panel1
      panel2
      # Add A Random Row
      self.createGroup(20, 10)

  #proc createWidget2: UXDockSession =
  #  self.root = dummy()
  #  result = docksession(self.root)
  #  let panel = dockpanel0test(20, 20)
  #  panel.add dockcontent("Nested Docks", self.createWidget())
  #  discard result.docks.child:
  #    panel

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