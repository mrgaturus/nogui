from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, widget, child
import nogui/ux/values/[chroma, linear, scroller]
import nogui/ux/prelude
import nogui/utf8
import nogui/pack
# Import All Widgets
import nogui/ux/widgets/[
  button,
  check,
  color,
  label,
  radio,
  scroll,
  textbox,
  menu,
  combo
]

import nogui/ux/widgets/menu/items

icons "tatlas", 16:
  brush := "brush.svg"
  clear := "clear.svg"
  reset := "reset.svg"
  #close := "close.svg"
  #color := "color.png"
  #right := "right.svg"
  #left := "left.svg"

# -----------------------
# Simple Widget Forwarder
# -----------------------

proc locate(self: GUIWidget, x, y: int32): GUIWidget =
  let metrics = addr self.metrics
  self.geometry(x, y, metrics.minW, metrics.minH)
  # Return Self
  self

proc locateW(self: GUIWidget, x, y, width: int32): GUIWidget =
  self.geometry(x, y, width, self.metrics.minH)
  # Return Self
  self

proc locateH(self: GUIWidget, x, y, height: int32): GUIWidget =
  self.geometry(x, y, self.metrics.minW, height)
  # Return Self
  self

proc locate(self: GUIWidget, x, y, w, h: int32): GUIWidget =
  self.geometry(x, y, w, h)
  # Return Self
  self

proc locate(self: GUIWidget, rect: GUIMetrics): GUIWidget =
  self.metrics = rect
  # Return Self
  self

# ---------------
# Dummy Container
# ---------------

widget GUIDummy:
  new dummy():
    result.flags = {wMouse}

  method layout =
    for w in forward(self.first):
      let m = addr w.metrics
      if m.w <= 0: m.w = m.minW
      if m.h <= 0: m.h = m.minh

widget GUIPanel:
  new panel():
    result.flags = {wMouse}

  method draw(ctx: ptr CTXRender) =
    ctx.color getApp().colors.panel
    ctx.fill rect(self.rect)

# ---------------------
# Controller Playground
# ---------------------

controller CXCallstackTest:
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

  callback cbInit:
    relax(self.cbPostpone0)
    relax(self.cbPostpone0)
    relax(self.cbPostpone1)
    send(self.cbFirst)
    send(self.cbSecond)
    echo getWindow().rect

  new cxcallstacktest():
    discard

controller CONPlayground:
  attributes:
    [a, b]: @ int32
    [check, check1]: @ bool
    [sv1, sv2]: @ Scroller
    [v1, v2]: @ Linear
    widget: GUIDummy
    text: UTF8Input
    color: RGBColor
    hsv0: @ HSVColor
    selected: ComboModel
    # Callstack Test
    cbtest: CXCallstackTest

  callback cbHelloWorld:
    echo "hello world"

  proc createWidget: GUIDummy =
    let
      cb = self.cbHelloWorld
      textRect = GUIMetrics(
        x: 500, y: 80,
        w: 400, h: 268
      )
    let cube = colorcube(self.hsv0)
    cube.metrics.minW = 128
    cube.metrics.minH = 128
    let circle = colorwheel(self.hsv0)
    circle.metrics.minW = 128
    circle.metrics.minH = 128
    let triangle = colorcube0triangle(self.hsv0)
    triangle.metrics.minW = 128
    triangle.metrics.minH = 128
    # Selection Items
    self.selected = 
      combomodel(): menu("").child:
          comboitem("Normal", iconBrush, 0)
          menuseparator("Dark")
          comboitem("Multiply", 1)
          comboitem("Darken", 2)
          comboitem("Color Burn", 3)
          comboitem("Linear Burn", 4)
          comboitem("Darker Color", 5)
          menuseparator("Light")
          comboitem("Screen", 6)
          comboitem("Lighten", 7)
          comboitem("Color Dodge", 8)
          comboitem("Linear Dodge", 9)
          comboitem("Lighter Color", 10)
          menuseparator("Contrast")
          comboitem("Overlay", 11)
          comboitem("Soft Light", 12)
          comboitem("Hard Light", 13)
          comboitem("Vivid Light", 14)
          comboitem("Linear Light", 15)
          comboitem("Pin Light", 16)
          menuseparator("Comprare")
          comboitem("Difference", 17)
          comboitem("Exclusion", 18)
          comboitem("Substract", 19)
          comboitem("Divide", 20)
          menuseparator("Composite")
          comboitem("Hue", 21)
          comboitem("Saturation", 22)
          comboitem("Color", 23)
          comboitem("Luminosity", 24)
    # Hello World Test
    self.selected.onchange = self.cbHelloWorld

    # Arrange Each Widget
    dummy().child:
      combobox(self.selected).glass().locateW(20, 400, 200)
      button("Hello World 2", self.cbtest.cbInit).locate(20, 55)
      # Locate Nested Buttons
      panel().locate(20, 80, 128, 128).child:
        button("Nested World", cb).locate(20, 10)
        button("Nested World 2", cb).locate(20, 35)
      # Locate Nested Sliders
      #panel().locate(160, 80, 128, 128).child:
      #  slider(addr self.v1).locateW(20, 10, 100)
      #  slider(addr self.v2).locateW(20, 35, 100)
      # Locate Nested Radio Buttons / Checkbox
      panel().locate(300, 80, 128, 268).child:
        radio("Option 1", 0, addr self.a).locateW(20, 10, 100)
        radio("Option 2", 1, addr self.a).locateW(20, 35, 100)
        # Checkboxes
        checkbox("Check 1", addr self.check).locateW(20, 70, 100)
        checkbox("Check 2", addr self.check).locateW(20, 95, 100)
        checkbox("Check 3", addr self.check1).locateW(20, 120, 100)
      # Locate Textbox
      panel().locate(160, 220, 128, 128).child:
        textbox(addr self.text).locateW(10, 10, 100)
        textbox(addr self.text).locateW(10, 35, 100)
      # Locate Scrollbars
      scrollbar(addr self.sv1, false).locateW(160, 360, 268)
      scrollbar(addr self.sv2, true).locateH(440, 80, 268)
      # Locate Top Labels
      panel().locate(textRect)
      label("Top-Left", hoLeft, veTop).locate(textRect)
      label("Top-Middle", hoMiddle, veTop).locate(textRect)
      label("Top-Right", hoRight, veTop).locate(textRect)
      # Locate Middle Labels
      label("Middle-Left", hoLeft, veMiddle).locate(textRect)
      label("Middle-Middle", hoMiddle, veMiddle).locate(textRect)
      label("Middle-Right", hoRight, veMiddle).locate(textRect)
      # Locate Right Labels
      label("Bottom-Left", hoLeft, veBottom).locate(textRect)
      label("Bottom-Middle", hoMiddle, veBottom).locate(textRect)
      label("Bottom-Right", hoRight, veBottom).locate(textRect)
      colorcube(addr self.hsv0).locate(265, 420, 150, 150)
      colorwheel(addr self.hsv0).locate(450, 420, 150, 150)
      #sv0triangle(addr self.hsv0).locate(655, 400, 150, 150)
      colorcube0triangle(addr self.hsv0).locate(40, 420, 200, 150)
      colorwheel0triangle(addr self.hsv0).locate(640, 420, 150, 150)
      #hue0bar(addr self.hsv0).locateH(425, 400, 150)
      #color0square(addr self.hsv0).locate(265, 400, 150, 150)
      #hue0circle(addr self.hsv0).locate(500, 400, 150, 150)

      menubar().locate(0, 0).child:
        # File Menu
        menu("File").child:
          menuitem("New", iconBrush, cb)
          menuitem("Open", iconClear, cb)
          menuseparator()
          menuitem("Save", iconReset, cb)
          menuitem("Save as", iconReset, cb)
          # Custom Widget
          menuseparator("Color Chooser")
          cube
          menuitem("About", cb)
          menuitem("Settings", cb)
          # More Menus
          menu("Other Menu").child:
            menuitem("Hello", cb)
            menuitem("World", cb)
            # More More Menus
            menu("Menu Menu").child:
              menuoption("Option A", addr self.a, 0)
              menuoption("Option B", addr self.a, 1)
              menuseparator()
              menucheck("Check A", addr self.check)
              menucheck("Check A Again", addr self.check)
              menucheck("Check B", addr self.check1)
          menu("Menu 2").child:
            menuitem("The", cb)
            menuitem("Game", cb)
            menuseparator("Color Circle")
            circle
            # More More Menus
            menu("Menu Menu").child:
              menuitem("World 2", cb)
              menuitem("World 2", cb)
          menuitem("Exit", cb)

        menu("Edit").child:
          menuitem("The", cb)
          menuitem("Game", cb)
          # More More Menus
          menu("Menu Other").child:
            menuitem("World Inside", cb)
            menuitem("World Inside", cb)
          menuseparator("Color Triangle")
          triangle

  new conplayground(a, b: cint):
    # Set New Values
    result.a = value(a)
    result.b = value(b)
    echo sizeof(result[])
    # Initialize Values
    result.v1 = value linear(20, 123)
    result.v2 = value linear(500, 268 * 8)
    # Create New Widget
    result.cbtest = cxcallstacktest()
    result.widget = result.createWidget()

# ---------
# Main Proc
# ---------

proc main() =
  createApp(1024, 600)
  let test = conplayground(10, 20)
  # Clear Color
  # Open Window
  executeApp(test.widget):
    let rgb = peek(test.hsv0)[].toRGB
    glClearColor(rgb.r, rgb.g, rgb.b, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()