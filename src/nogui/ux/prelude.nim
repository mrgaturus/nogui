# Import GUI Builder
from ../builder import widget, controller
# Import GUI Native Platform
from ../native/ffi import
  GUIEvent, GUITool,
  GUIKeycode, GUIKeymod, GUIState, mods, name
from ../native/cursor import GUICursorSys
# Import GUI Core
import ../core/[widget, metrics, render, atlas, callback, value, window]
from ../core/timer import timeout, timestop
# Import Global App State
from ../../nogui import
  getApp,
  getWindow,
  width, index
# Import Icon ID Helper
from ../data import
  CTXIconID,
  CTXCursorID,
  CTXIconEmpty, `==`
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
proc clearColor*(self: GUIWidget): uint32 =
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
  ffi.name,
  # Export Cursor
  GUICursorSys

export builder.widget
export builder.controller
export widget
export metrics except
  GUIClipping,
  push, pop, clear, peek
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
export callback except
  createMessenger,
  destroyMessenger,
  nogui_coroutine_pump
export timeout, timestop
# Export Global App State
export getApp, getWindow, width, index
export window except
  GUIWindow,
  newGUIWindow,
  execute, render, poll
# Export Constant Icon ID
export
  CTXIconID,
  CTXIconEmpty,
  CTXCursorID,
  data.`==`
# Export Shared Values
export value
export privateAccess
