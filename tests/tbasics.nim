# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

#import unittest

import nogui/libs/gl
import nogui/libs/ft2
import nogui/gui/[window, widget, render, event, signal, timer]
from nogui/gui/widgets/button import button
from nogui/gui/widgets/check import checkbox
from nogui/gui/widgets/radio import radio
from nogui/gui/widgets/textbox import textbox
from nogui/gui/widgets/slider import slider
from nogui/gui/widgets/scroll import scrollbar
from nogui/gui/widgets/color import colorbar
from nogui/builder import widget
import nogui/gui/widgets/label
from nogui/gui/atlas import width
from nogui/gui/config import metrics, theme
from nogui/values import Value, interval, lerp, RGBColor
#from nogui/assets import icons
from nogui/utf8 import UTF8Input, `text=`

# -------------------
# TEST TOOLTIP WIDGET
# -------------------

widget GUITooltip:
  new tooltip():
    discard

  method draw(ctx: ptr CTXRender) =
    ctx.color theme.bgWidget
    ctx.fill rect(self.rect.x, self.rect.y, 
      "TEST TOOLTIP".width, metrics.fontSize)
    ctx.color theme.text
    ctx.text(self.rect.x, self.rect.y, "TEST TOOLTIP")

  method update =
    if self.test(wVisible):
      self.close()
    else: self.open()

# ------------------------
# TEST MENU WIDGET PROTOTYPE
# ------------------------
#[
type
  GUIMenuKind = enum
    mkMenu, mkAction
  GUIMenuItem = object
    name: string
    width: int32
    case kind: GUIMenuKind:
    of mkMenu:
      menu: GUIMenu
    of mkAction:
      cb: GUICallback
  GUIMenu = ref object of GUIWidget
    hover, submenu: int32
    bar: GUIMenuBar
    items: seq[GUIMenuItem]
  GUIMenuTile = object
    name: string
    width: int32
    menu: GUIMenu
  GUIMenuBar = ref object of GUIWidget
    grab: bool
    hover: int32
    items: seq[GUIMenuTile]

# -- Both Menus --
proc add(self: GUIMenuBar, name: string, menu: GUIMenu) =
  menu.bar = self # Set Menu
  menu.kind = wgPopup
  self.items.add GUIMenuTile(
    name: name, menu: menu)

proc add(self: GUIMenu, name: string, menu: GUIMenu) =
  if menu != self: # Avoid Cycle
    menu.kind = wgMenu
    self.items.add GUIMenuItem(
      name: name, menu: menu, kind: mkMenu)

proc add(self: GUIMenu, name: string, cb: GUICallback) =
  self.items.add GUIMenuItem( # Add Callback
    name: name, cb: cb, kind: mkAction)

# -- Standard Menu
proc newMenu(): GUIMenu =
  new result # Alloc
  # Define Atributes
  result.flags = wMouse
  result.hover = -1
  result.submenu = -1

method layout(self: GUIMenu) =
  var # Max Width/Height
    mw, mh: int32
  for item in mitems(self.items):
    mw = max(mw, item.name.width)
    mh += metrics.fontSize
  # Set Dimensions
  self.rect.w = # Reserve Space
    mw + (metrics.fontSize shl 1)
  self.rect.h = mh + 4

method draw(self: GUIMenu, ctx: ptr CTXRender) =
  var 
    offset = self.rect.y + 2
    index: int32
  let x = self.rect.x + (metrics.fontSize)
  # Draw Background
  ctx.color theme.bgContainer
  ctx.fill rect(self.rect)
  ctx.color theme.text
  # Draw Each Menu
  for item in mitems(self.items):
    if self.hover == index:
      ctx.color theme.hoverWidget
      var r = rect(self.rect)
      r.y = offset.float32
      r.yh = r.y + float32(metrics.fontSize)
      ctx.fill(r)
      ctx.color theme.text
    ctx.text(x, offset - metrics.descender, item.name)
    offset += metrics.fontSize
    inc(index) # Next Index
  ctx.color theme.bgWidget
  ctx.line rect(self.rect), 1

method event(self: GUIMenu, state: ptr GUIState) =
  case state.kind
  of evCursorClick, evCursorMove:
    if self.test(wHover):
      var # Search Hovered Item
        index: int32
        cursor = self.rect.y + 2
      for item in mitems(self.items):
        let space = cursor + metrics.fontSize
        if state.my > cursor and state.my < space:
          case item.kind
          of mkMenu: # Submenu
            if state.kind == evCursorMove and index != self.submenu:
              if self.submenu >= 0 and self.items[self.submenu].kind == mkMenu:
                close(self.items[self.submenu].menu)
              # Open new Submenu
              open(item.menu)
              item.menu.move(self.rect.x + self.rect.w - 1, cursor - 2)
              self.submenu = index
          of mkAction: # Callback
            if state.kind == evCursorClick:
              pushCallback(item.cb)
              self.close()
              if not isNil(self.bar):
                self.bar.grab = false
          # Menu Item Found
          self.hover = index; return
        # Next Menu
        cursor = space
        inc(index)
    elif not isNil(self.bar) and # Use Menu Bar
    pointOnArea(self.bar, state.mx, state.my):
      self.bar.event(state)
    elif state.kind == evCursorClick:
      self.close() # Close Menu
      if not isNil(self.bar):
        self.bar.grab = false
    self.hover = -1 # Remove Current Hover
  else: discard

method handle(self: GUIMenu, kind: GUIHandle) =
  case kind
  of outFrame: # Close Submenu y Close is requested
    if self.submenu >= 0 and self.items[self.submenu].kind == mkMenu:
      close(self.items[self.submenu].menu)
    self.submenu = -1
  else: discard

# -- Menu Bar
proc newMenuBar(): GUIMenuBar =
  new result # Alloc
  # Define Atributes
  result.flags = wMouse
  result.hover = -1
  result.minimum(0, metrics.fontSize)

method layout(self: GUIMenuBar) =
  # Get Text Widths
  for menu in mitems(self.items):
    menu.width = menu.name.width

method draw(self: GUIMenuBar, ctx: ptr CTXRender) =
  # Draw Background
  ctx.color theme.bgWidget
  ctx.fill rect(self.rect)
  # Draw Each Menu
  var # Iterator
    index: int32
    cursor: int32 = self.rect.x
    r: CTXRect
  r.y = float32(self.rect.y)
  r.yh = r.y + float32(self.metrics.h)
  # Set Text Color
  ctx.color theme.text
  for item in mitems(self.items):
    if self.hover == index:
      # Set Hover Color
      ctx.color theme.hoverWidget
      # Define Rect
      r.x = cursor.float32
      r.xw = r.x + 4 +
        float32(item.width)
      # Fill Rect
      ctx.fill(r)
      # Return Text Color
      ctx.color theme.text
    cursor += 2
    ctx.text(cursor, 
      self.rect.y + 2, item.name)
    cursor += item.width + 2
    inc(index) # Current Index

method event(self: GUIMenuBar, state: ptr GUIState) =
  case state.kind
  of evCursorClick, evCursorMove:
    var # Search Hovered Item
      cursor = self.rect.x
      index: int32
    for item in mitems(self.items):
      let space = cursor + item.width + 4
      if state.mx > cursor and state.mx < space:
        if state.kind == evCursorClick:
          if item.menu.test(wVisible):
            close(item.menu)
            self.grab = false
          else: # Open Popup
            self.grab = true
            open(item.menu)
          item.menu.move(cursor,
            self.rect.y + self.rect.h)
        elif self.grab and self.hover >= 0 and
        index != self.hover:
          # Change Menu To Other
          close(self.items[self.hover].menu)
          open(item.menu)
          item.menu.move(cursor,
            self.rect.y + self.rect.h)
        self.hover = index; break
      # Next Menu
      cursor = space
      inc(index)
  else: discard
]#
# -----------------------
# TEST MISC WIDGETS STUFF
# -----------------------

type
  Counter = object
    clicked, released: int

widget GUIFondo:
  attributes:
    color: uint32

  new newGUIFondo(): discard

  method draw(ctx: ptr CTXRender) =
    ctx.color if self.test(wHover):
      self.color or 0xFF000000'u32
    else: self.color
    ctx.fill rect(self.rect)

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      if not self.test(wHover):
        self.close() # Close

var coso: UTF8Input
proc helloworld*(g, d: pointer) =
  coso.text = "hello world"
  echo "hello world"

# ------------------
# GUI BLANK METHODS
# ------------------

widget GUIBlank:
  attributes:
    frame: GUIWidget
    texture: GLuint

  new newGUIBlank(): discard

  method draw(ctx: ptr CTXRender) =
    ctx.color if self.test(wHover):
      0xFF7f7f7f'u32
    else: 0xFFFFFFFF'u32
    ctx.fill rect(self.rect)
    ctx.texture(rect self.rect, self.texture)

  method event(state: ptr GUIState) =
    case state.kind
    of evCursorClick:
      if state.key == MiddleButton:
        echo "middle button xdd"
      if not isNil(self.frame) and test(self.frame, wVisible):
        close(self.frame)
      else:
        pushTimer(self.target, 1000)
        self.set(wFocus)
    of evCursorRelease:
      # Remove Timer
      echo "w timer removed"
      stopTimer(self.target)
    of evKeyDown:
      echo "tool kind: ", state.tool
      echo " -- mouse  x: ", state.mx
      echo " -- stylus x: ", state.px
      echo ""
      echo " -- mouse  y: ", state.my
      echo " -- stylus y: ", state.py
      echo ""
      echo " -- pressure: ", state.pressure
      echo ""
    else: discard
    if self.test(wGrab) and not isNil(self.frame):
      move(self.frame, state.mx + 5, state.my + 5)

  method update =
    echo "w timer open frame"
    if self.frame != nil:
      open(self.frame)
    # Remove Timer
    stopTimer(self.target)

  method handle(kind: GUIHandle) =
    echo "handle done: ", kind.repr
    echo "by: ", cast[uint](self)

proc blend*(dst, src: uint32): uint32{.importc: "blend_normal".}
proc fill*(buffer: var seq[uint32], x, y, w, h: int32, color: uint32) =
  var i, xi, yi: int32
  yi = y
  while i < h:
    xi = x
    while xi < w:
      let col = buffer[yi * w + xi]
      buffer[yi * w + xi] = blend(col, color)
      inc(xi)
    inc(i); inc(yi)

proc exit(a, b: pointer) =
  pushSignal(msgTerminate)

proc world(a, b: pointer) =
  echo "Hello World"

when isMainModule:
  var counter = Counter(
    clicked: 0, 
    released: 0
  )
  var win = newGUIWindow(1024, 600, addr counter)
  var ft: FT2Library
  var cpu_raster: GLuint
  var cpu_pixels: seq[uint32]
  var bolo, bala: bool
  var equisde: byte
  var val: Value
  var val2: Value
  var col = RGBColor(r: 50 / 255, g: 50 / 255, b: 50 / 255)
  val2.interval(0, 100)
  val.interval(0, 5)
  val.lerp(0.5)
  
  # Generate CPU Raster
  cpu_pixels.setLen(512 * 256)
  glGenTextures(1, addr cpu_raster)
  glBindTexture(GL_TEXTURE_2D, cpu_raster)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, cast[GLint](GL_LINEAR))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, cast[GLint](GL_NEAREST))
  glTexImage2D(GL_TEXTURE_2D, 0, cast[GLint](GL_RGBA8), 512, 256, 
    0, GL_RGBA, GL_UNSIGNED_BYTE, nil)
  glBindTexture(GL_TEXTURE_2D, 0)

  # Initialize Freetype2
  if ft2_init(addr ft) != 0:
    echo "ERROR: failed initialize FT2"
  # Create a new Window
  let root = newGUIFondo()
  #[
  block: # Create Menu Bar
    var bar = newMenuBar()
    var menu: GUIMenu
    # Create a Menu
    menu = newMenu()
    menu.add("Hello World", world)
    menu.add("Exit A", exit)
    bar.add("File", menu)
    # Create Other Menu
    menu = newMenu()
    menu.add("Hello World", world)
    menu.add("Exit B", exit)
    bar.add("Other", menu)
    block: # SubMenu
      var sub = newMenu()
      sub.add("Hello Inside", world)
      sub.add("Kill Program", exit)
      menu.add("The Game", sub)
    # Add Menu Bar to Root Widget
    bar.geometry(20, 160, 200, bar.metrics.h)
    root.add(bar)
  ]#
  block: # Create Widgets
    # Create two blanks
    var
      sub, blank: GUIBlank
      con: GUIFondo
    # Initialize Root
    root.color = 0xFF323232'u32
    # --- Blank #1 ---
    blank = newGUIBlank()
    blank.geometry(300,150,512,256)
    blank.texture = cpu_raster
    root.add(blank)
    # --- Blank #2 ---
    blank = newGUIBlank()
    blank.flags = wMouse
    blank.geometry(20,20,100,100)
    blank.texture = cpu_raster
    block: # Menu Blank #2
      con = newGUIFondo()
      con.flags = wMouse
      con.color = 0xAA637a90'u32
      con.rect.w = 200
      con.rect.h = 100
      # Sub-Blank #1
      sub = newGUIBlank()
      sub.geometry(10,10,20,20)
      con.add(sub)
      # Sub-Blank #2
      sub = newGUIBlank()
      sub.flags = wMouse
      sub.geometry(40,10,20,20)
      block: # Sub Menu #1
        let subcon = newGUIFondo()
        subcon.flags = wMouse
        subcon.color = 0x72bdb88f'u32
        subcon.rect.w = 300
        subcon.rect.h = 80
        # Sub-sub blank 1#
        var subsub = newGUIBlank()
        subsub.geometry(10,10,80,20)
        subcon.add(subsub)
        # Sub-sub blank 2#
        subsub = newGUIBlank()
        subsub.geometry(10,40,80,20)
        subcon.add(subsub)
        # Add Sub to Sub
        block: # Sub Menu #1
          let fondo = newGUIFondo()
          fondo.color = 0x64000000'u32
          fondo.geometry(90, 50, 300, 80)
          # Sub-sub blank 1#
          var s = newGUIBlank()
          s.geometry(10,10,20,20)
          fondo.add(s)
          # Sub-sub blank 2#
          s = newGUIBlank()
          echo s.vtable.repr
          s.geometry(10,40,20,20)
          fondo.add(s)
          # Add Fondo to sub
          subcon.add(fondo)
        # Add to Sub
        subcon.kind = wgPopup
        sub.frame = subcon
      con.add(sub)
      # Add Blank 2
      con.kind = wgFrame
      blank.frame = con
    root.add(blank)
    # Add a GUI Button
    let button = button("Test Button CB", helloworld)
    button.geometry(20, 200, 200, button.metrics.minH)
    block: # Add Checkboxes
      var check = checkbox("Check B", addr bolo)
      check.geometry(20, 250, 100, check.metrics.minH)
      root.add(check)
      check = checkbox("Check A", addr bala)
      check.geometry(120, 250, 100, check.metrics.minH)
      root.add(check)
    block: # Add Radio Buttons
      var radio = radio("Radio B", 1, addr equisde)
      radio.geometry(20, 300, 100, radio.metrics.minH)
      root.add(radio)
      radio = radio("Radio A", 2, addr equisde)
      radio.geometry(120, 300, 100, radio.metrics.minH)
      root.add(radio)
    block: # Add TextBox
      var textbox = textbox(addr coso)
      textbox.geometry(20, 350, 200, textbox.metrics.minH)
      root.add(textbox)
    block: # Add Slider
      var slider = slider(addr val, 0)
      slider.geometry(20, 400, 200, slider.metrics.minH)
      root.add(slider)
    block: # Add Scroll
      var scroll = scrollbar(addr val, false)
      scroll.geometry(20, 450, 200, scroll.metrics.minH)
      root.add(scroll)
    block: # Add Scroll
      var scroll = scrollbar(addr val, true)
      scroll.geometry(20, 480, scroll.metrics.minH, 200)
      root.add(scroll)
    block: # Add Scroll
      var color = colorbar(addr col)
      color.geometry(50, 500, color.metrics.minW * 2, color.metrics.minH * 2)
      root.add(color)
      color = colorbar(addr col)
      color.geometry(300, 500, color.metrics.minW * 2, color.metrics.minH * 2)
      root.add(color)
    block: # Add Labels
      var label: GUIWidget
      let rect = GUIRect(
        x: 550, y: 500, w: 200, h: 100)
      let button = button("", nil)
      button.geometry rect
      root.add button
      # Right Align
      label = label("TEST TEXT", hoRight, veTop)
      label.rect = rect; label.geometry rect; root.add(label)
      label = label("TEST TEXT", hoRight, veMiddle)
      label.rect = rect; label.geometry rect; root.add(label)
      label = label("TEST TEXT", hoRight, veBottom)
      label.rect = rect; label.geometry rect; root.add(label)
      # Middle Align
      label = label("TEST TEXT", hoMiddle, veTop)
      label.rect = rect; label.geometry rect; root.add(label)
      label = label("TEST TEXT", hoMiddle, veMiddle)
      label.rect = rect; label.geometry rect; root.add(label)
      label = label("TEST TEXT", hoMiddle, veBottom)
      label.rect = rect; label.geometry rect; root.add(label)
      # Left Align
      label = label("TEST TEXT", hoLeft, veTop)
      label.rect = rect; label.geometry rect; root.add(label)
      label = label("TEST TEXT", hoLeft, veMiddle)
      label.rect = rect; label.geometry rect; root.add(label)
      label = label("TEST TEXT", hoLeft, veBottom)
      label.rect = rect; label.geometry rect; root.add(label)
    root.add(button)
  # Create a random tooltip
  var tp = tooltip()
  tp.kind = wgTooltip
  tp.rect.x = 40
  tp.rect.y = 180
  echo tp.vtable.repr
  # Open Window
  if win.open(root):
    pushTimer(tp.target, 1000)
    loop(16):
      win.handleEvents() # Input
      if win.handleSignals(): break
      win.handleTimers() # Timers
      # Render Main Program
      glClearColor(0.5, 0.5, 0.5, 1.0)
      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
      # Render GUI
      win.render()
  # Close Window
  win.close()
