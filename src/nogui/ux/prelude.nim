# Import GUI Toolkit Core
from ../builder import widget, controller
from ../native/ffi import
  GUIEvent, GUITool,
  GUIKeycode, GUIKeymod, GUIState, mods, name
import ../core/[widget, render, atlas, callback, value]
from ../core/timer import timeout, timestop
# Import Window Manipulation
from ../core/window import
  WindowMessage, WidgetMessage,
  send, relax, shorts, observers
# Import Global App State
from ../../nogui import
  getApp,
  getWindow,
  width, index
# Import Icon ID Helper
from ../data import CTXIconID, CTXIconEmpty, `==`
# Import Private Access
from std/importutils import privateAccess

# -------------------
# GUI Widget Callback
# -------------------

proc send*(widget: GUIWidget, msg: WidgetMessage) =
  getWindow().send(widget, msg)

proc relax*(widget: GUIWidget, msg: WidgetMessage) =
  getWindow().relax(widget, msg)

# ------------------------
# GUI Control Color Helper
# ------------------------

template colorControl(self: GUIWidget, idle, hover, click: uint32): uint32 =
  const wHoverGrab = {wHover, wGrab}
  let flags = self.flags * wHoverGrab
  # Choose Which Color Using State
  if flags == {}: idle
  elif flags == wHoverGrab: click
  else: hover

# -- Toggle Button Colors
proc opaqueColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(0'u32, c.focus, c.clicked)

proc activeColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(c.clicked, c.focus, c.item)

# -- Item Button Colors
proc optionColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(c.darker, c.focus, c.clicked)

proc itemColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(c.item, c.focus, c.clicked)

# -----------------
# Exporting Prelude
# -----------------

export
  GUIEvent,
  GUITool,
  GUIKeycode,
  GUIKeymod,
  GUIState,
  ffi.mods,
  ffi.name

export builder.widget
export widget
export render except 
  newCTXRender,
  begin, 
  viewport, 
  clear, 
  render,
  finish
export atlas except
  newGUIAtlas,
  createTexture,
  checkTexture
# Export Event and Callback Stuff
export callback except messenger
export timeout, timestop
# Export Global App State
export getApp, getWindow, width, index
export WindowMessage, WidgetMessage
export window.send, window.relax
export window.shorts, window.observers
# Export Constant Icon ID
export CTXIconID, CTXIconEmpty, data.`==`
# Export Shared Values
export value
export privateAccess
