from ../builder import widget
# Import Widget and Rendering
import ../core/[widget, event, render, atlas, signal, value]
# Import Event and Callback Stuff
from ../core/timer import pushTimer, stopTimer
# Import Global App State
from ../../nogui import getApp, width, index
# Import Icon ID Helper
from ../data import CTXIconID, CTXIconEmpty, `==`
# Import Private Access
from std/importutils import privateAccess

# ------------------------
# GUI Control Color Helper
# ------------------------

proc colorControl*(self: GUIWidget, idle, hover, click: uint32): uint32 {.inline.} =
  let flags = self.flags and wHoverGrab
  # Choose Which Color Using State
  if flags == 0: idle
  elif flags == wHoverGrab: click
  else: hover

# --------------------
# Toggle Button Colors
# --------------------

proc opaqueColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(0, c.focus, c.clicked)

proc activeColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(c.clicked, c.focus, c.item)

# ------------------
# Item Button Colors
# ------------------

proc optionColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(c.darker, c.focus, c.clicked)

proc itemColor*(self: GUIWidget): uint32 =
  let c = addr getApp().colors
  self.colorControl(c.item, c.focus, c.clicked)

# -----------------
# Exporting Prelude
# -----------------

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
export event except
  newGUIState,
  translateX11Event,
  utf8state
export signal except newGUIQueue
export pushTimer, stopTimer
# Export Relevant Global State
export getApp, width, index
# Export Constant Icon ID
export CTXIconID, CTXIconEmpty, data.`==`
# Export Shared Values
export value
# Export Private Access
export privateAccess
