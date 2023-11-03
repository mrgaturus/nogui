from nogui/pack import folders
from nogui/data import newFont
from nogui/gui/widget import GUIWidget
from nogui/gui/timer import loop
from nogui/gui/signal import 
  GUIQueue, newGUIQueue, dispose

import nogui/libs/ft2
import nogui/gui/[window, atlas]
import nogui/[logger, format, utf8]

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
  Application = object
    window: GUIWindow
    queue: GUIQueue
    state: pointer
    # Text Layout
    ft2*: FT2Library
    atlas*: CTXAtlas
    # Atlas Font Metrics
    font*: GUIFont
    colors*: GUIColors
    # TODO: reuse it for event ut8buffer
    fmt0: CacheString
  GUIApplication = ptr Application

# -----------------------
# Application Destruction
# -----------------------

proc `=destroy`(app: Application) =
  log(lvInfo, "closing application...")
  # Close Window and Queue
  close(app.window)
  dispose(app.queue)
  # Dealloc Freetype 2
  if ft2_done(app.ft2) != 0:
    log(lvError, "failed closing FreeType2")

# Global Application Handle
var app: Application

# -----------------------
# Private Common Creation
# -----------------------

proc createColors(): GUIColors =
  # TODO: create a module for colors and allow config file
  proc rgba(r, g, b, a: uint32): uint32 {.compileTime.} =
    result = r or (g shl 8) or (b shl 16) or (a shl 24)  
  # Text Colors
  result.text = rgba(224, 224, 224, 255)
  # Widget Controls
  result.item = rgba(44, 48, 48, 255)
  result.focus = rgba(64, 71, 71, 255)
  result.clicked = rgba(87, 95, 95, 255)
  # Widget Panels
  result.panel = rgba(14, 15, 15, 247)
  result.tab = rgba(19, 21, 21, 255)
  result.darker = rgba(0, 0, 0, 255)
  result.background = rgba(23, 26, 26, 255)
  echo result.repr

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
  var ft2: FT2Library
  let result = addr app
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
  # Copy Default Data
  static: folders: "data" >> ""

proc getApp*(): GUIApplication =
  # Check App Initialize
  when defined(debug):
    if isNil(app.queue):
      log(lvError, "app is not initialized")
  # Return Current App
  result = addr app

template executeApp*(root: GUIWidget, body: untyped) =
  let win {.cursor.} = app.window
  if win.open(root):
    # TODO: allow configure ms
    loop(16):
      # TODO: unify all into one queue
      handleEvents(win)
      if handleSignals(win): break
      handleTimers(win)
      # Execute Body
      body; render(win)

# ------------------------
# Alloc-Less Format Export
# ------------------------

# Shallow String Lookup
proc fmt*(app: GUIApplication):
  ShallowString {.inline.} = addr app.fmt0

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

# -----------------------------------------
# TODO: expose public apis for window after
#       rewriting x11 platforms to C
# -----------------------------------------

proc setCursor*(app: GUIApplication, code: int) =
  setCursor(app.window, code)

proc setCursor*(app: GUIApplication, name: cstring) =
  setCursor(app.window, name)

proc setCursorCustom*(app: GUIApplication, custom: Cursor) =
  setCursorCustom(app.window, custom)

proc clearCursor*(app: GUIApplication) =
  clearCursor(app.window)
