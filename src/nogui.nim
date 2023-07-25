from nogui/data import folders
from nogui/loader import newFont
from nogui/gui/widget import GUIWidget
from nogui/gui/timer import loop
from nogui/gui/signal import 
  GUIQueue, newGUIQueue, dispose

import nogui/libs/ft2
import nogui/gui/[window, atlas]
import nogui/[logger, utf8]

type
  GUIColors = object
    text*: uint32
    # Widget Controls
    item*: uint32
    focus*, clicked*: uint32
    # Widget Panels
    panel*, tab*, darker*: uint32
    background*: uint32
  GUIFont = object
    face: FT2Face
    # Glyph Metrics
    size*, height*: int16
    asc*, desc*, baseline*: int16
  # Global Application Handle
  GUIApplication = ref object
    window: GUIWindow
    queue: GUIQueue
    state: pointer
    # Text Layout
    ft2*: FT2Library
    atlas*: CTXAtlas
    # Atlas Font Metrics
    font*: GUIFont
    colors*: GUIColors
# Global Application Handle
var app: GUIApplication

# -----------------------
# Private Common Creation
# -----------------------

proc createColors(): GUIColors =
  # TODO: allow load from a config file
  discard

proc createFont(ft2: FT2Library): GUIFont =
  const hardsize = 9
  let 
    face = newFont(ft2, "font.ttf", hardsize)
    # Font Metrics
    m = addr face.size.metrics
    asc = m.ascender
    desc = m.descender
    baseline = asc + desc
  # Initialize Metrics
  result.size = hardsize
  result.height = cast[int16](m.height shr 6)
  result.asc = cast[int16](asc shr 6)
  result.desc = cast[int16](desc shr 6)
  result.baseline = cast[int16](baseline shr 6)
  # Set Current Face
  result.face = face

# --------------------
# Application Creation
# --------------------

proc createApp*(w, h: int32, state: pointer) =
  var 
    result: GUIApplication
    ft2: FT2Library
  # Create Application
  new result
  # Create Freetype
  if ft2_init(addr ft2) != 0:
    log(lvError, "failed initialize FreeType2")
  # Create Private Common
  result.ft2 = ft2
  result.colors = createColors()
  result.font = createFont(ft2)
  # Create Queue, Atlas and then Window
  let 
    queue = newGUIQueue(state)
    atlas = newCTXAtlas(result.font.face)
  result.window = newGUIWindow(w, h, queue, atlas)
  result.queue = queue
  result.atlas = atlas
  # Set New Application
  app = result
  # Copy Default Data
  static: folders: "data" *= "./"

proc getApp*(): GUIApplication =
  # Check App Initialize
  when defined(debug):
    if isNil(app):
      log(lvError, "app is not initialized")
  # Return Current App
  result = app

template executeApp*(root: GUIWidget, body: untyped) =
  let win {.cursor.} = getApp().win
  if win.open(root):
    # TODO: allow configure ms
    loop(16):
      win.handleEvents()
      if win.handleSignals(): break
      win.handleTimers()
      # Execute Body
      body; win.render()

proc closeApp*() =
  # Close Window and Queue
  close(app.window)
  dispose(app.queue)
  # Dealloc Freetype 2
  discard ft2_done(app.ft2)

# ------------
# Font Metrics
# ------------

proc width*(str: string): int32 =
  let atlas = app.atlas
  # Iterate Charcodes
  for rune in runes16(str):
    result += atlas.glyph(rune).advance

proc width*(str: string, l: int32): int32 =
  var # Iterator
    i: int32
    rune: uint16
  # Iterate Charcodes
  let atlas = app.atlas
  while i < l:
    rune16(str, i, rune) # Decode Rune
    result += atlas.glyph(rune).advance

proc index*(str: string, w: int32): int32 =
  var # Iterator
    i: int32
    rune: uint16
    advance: int16
  # Iterate Charcodes
  let atlas = app.atlas
  while result < len(str):
    rune16(str, i, rune) # Decode Rune
    advance = atlas.glyph(rune).advance
    # Substract expected Width
    unsafeAddr(w)[] -= advance
    if w > 0: result = i
    else: # Check Half Advance
      if w + (advance shr 1) > 0:
        result = i
      break
