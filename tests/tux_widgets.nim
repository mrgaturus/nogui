from nogui/libs/gl import 
  glClear, 
  glClearColor, 
  GL_COLOR_BUFFER_BIT, 
  GL_DEPTH_BUFFER_BIT
from nogui import createApp, executeApp
from nogui/builder import controller, widget, child
import nogui/values
import nogui/ux/prelude
import nogui/utf8
# Import All Widgets
import nogui/ux/widgets/[
  button,
  check,
  color_bad,
  color,
  label,
  radio,
  scroll,
  slider,
  textbox
]
import nogui/ux/widgets/color/[hue, saturate]

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
    result.flags = wMouse

widget GUIPanel:
  new panel():
    result.flags = wMouse

  method draw(ctx: ptr CTXRender) =
    ctx.color getApp().colors.panel
    ctx.fill rect(self.rect)

# ---------------------
# Controller Playground
# ---------------------

controller CONPlayground:
  attributes:
    [a, b]: int32
    [check, check1]: bool
    [v1, v2]: Value
    widget: GUIDummy
    text: UTF8Input
    color: RGBColor
    hsv0: HSVColor

  callback cbHelloWorld:
    echo "hello world"

  proc createWidget: GUIDummy =
    let 
      cb = self.cbHelloWorld
      textRect = GUIMetrics(
        x: 500, y: 60,
        w: 400, h: 268
      )
    # Arrange Each Widget
    dummy().child:
      button("Hello World", cb).locate(20, 10)
      button("Hello World 2", cb).locate(20, 35)
      # Locate Nested Buttons
      panel().locate(20, 60, 128, 128).child:
        button("Nested World", cb).locate(20, 10)
        button("Nested World 2", cb).locate(20, 35)
      # Locate Nested Sliders
      panel().locate(160, 60, 128, 128).child:
        slider(addr self.v1).locateW(20, 10, 100)
        slider(addr self.v2).locateW(20, 35, 100)
      # Locate Nested Radio Buttons / Checkbox
      panel().locate(300, 60, 128, 268).child:
        radio("Option 1", 0, addr self.a).locateW(20, 10, 100)
        radio("Option 2", 1, addr self.a).locateW(20, 35, 100)
        # Checkboxes
        checkbox("Check 1", addr self.check).locateW(20, 70, 100)
        checkbox("Check 2", addr self.check).locateW(20, 95, 100)
        checkbox("Check 3", addr self.check1).locateW(20, 120, 100)
      # Locate Textbox
      panel().locate(160, 200, 128, 128).child:
        textbox(addr self.text).locateW(10, 10, 100)
        textbox(addr self.text).locateW(10, 35, 100)
      # Locate Color Bar
      colorbar(addr self.color).locate(20, 200, 128, 128)
      colorbar(addr self.color).locate(80, 400, 148, 128)
      # Locate Scrollbars
      scrollbar(addr self.v1, false).locateW(160, 340, 268)
      scrollbar(addr self.v2, true).locateH(440, 60, 268)
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
      colorcube(addr self.hsv0).locate(265, 400, 150, 150)
      colorwheel(addr self.hsv0).locate(450, 400, 150, 150)
      #hue0bar(addr self.hsv0).locateH(425, 400, 150)
      #color0square(addr self.hsv0).locate(265, 400, 150, 150)
      #hue0circle(addr self.hsv0).locate(500, 400, 150, 150)

  new conplayground(a, b: cint):
    # Set New Values
    result.a = a
    result.b = b
    echo sizeof(result[])
    # Initialize Values
    interval(result.v1, 20, 123)
    interval(result.v2, 500, 268 * 8)
    # Create New Widget
    result.widget = result.createWidget()

# ---------
# Main Proc
# ---------

proc main() =
  createApp(1024, 600, nil)
  let test = conplayground(10, 20)
  # Clear Color
  let
    bg = getApp().colors.background
    r = float32(bg and 0xFF) / 255
    g = float32(bg shr 8 and 0xFF) / 255
    b = float32(bg shr 16 and 0xFF) / 255
  # Open Window
  executeApp(test.widget):
    glClearColor(r, g, b, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()