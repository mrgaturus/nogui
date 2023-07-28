from ../builder import widget
# Import Widget and Rendering
import ../gui/[widget, render, atlas, signal]
# Import Event and Callback Stuff
from ../gui/event import GUIState, GUIEvent
from ../gui/timer import pushTimer, stopTimer
# Import Global App State
from ../../nogui import getApp, width, index

# -----------------------
# Standard Color Choosing
# -----------------------

proc optionColor*(self: GUIWidget): uint32 =
  let colors = addr getApp().colors
  if not self.any(wHoverGrab):
    colors.darker
  elif self.test(wHoverGrab):
    colors.clicked
  else: colors.focus

proc itemColor*(self: GUIWidget): uint32 =
  let colors = addr getApp().colors
  if not self.any(wHoverGrab):
    colors.item
  elif self.test(wHoverGrab):
    colors.clicked
  else: colors.focus

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
export GUIState, GUIEvent
export signal except newGUIQueue
export pushTimer, stopTimer
# Export Relevant Global State
export getApp, width, index
