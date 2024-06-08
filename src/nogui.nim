from nogui/pack import folders
from nogui/data import newFont
from nogui/core/widget import GUIWidget
from nogui/core/timer import loop

import nogui/libs/ft2
import nogui/native/ffi
import nogui/core/[window, atlas]
import nogui/[logger, format, utf8]
# OpenGL Pointer Loader
from nogui/libs/gl import gladLoadGL

type
  GUISpace = object
    margin*: int16
    pad*: int16
    line*: int16
    # Layout Separators
    sepX*, sepY*: int16
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
    native: ptr GUINative
    state*: ptr GUIState
    # Freetype Font
    ft2*: FT2Library
    atlas*: CTXAtlas
    # Font Metrics
    font*: GUIFont
    space*: GUISpace
    colors*: GUIColors
    # Format String
    fmt0: CacheString
    fmt*: ShallowString
  GUIApplication = ptr Application

# -----------------------
# Application Destruction
# -----------------------

proc `=destroy`(app: Application) =
  log(lvInfo, "closing application...")
  # Destroy Native Platform
  destroy(app.window)
  nogui_native_destroy(app.native)
  # Dealloc Freetype 2
  if ft2_done(app.ft2) != 0:
    log(lvError, "failed closing FreeType2")

# Global Application Handle
var app: Application

# -----------------------
# Private Common Creation
# -----------------------

proc createSpace(): GUISpace =
  result.margin = 4
  result.pad = 6
  result.line = 2
  # Layout Separators
  result.sepX = 2
  result.sepY = 2

proc createColors(): GUIColors =
  # TODO: create a module for config file
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

proc createApp*(w, h: int32) =
  var ft2: FT2Library
  let result = addr app
  # Create Freetype
  if ft2_init(addr ft2) != 0:
    log(lvError, "failed initialize FreeType2")
  # Create Private Common
  result.ft2 = ft2
  result.colors = createColors()
  result.space = createSpace()
  result.font = createFont(ft2)
  # Create Native Platform
  let
    native = nogui_native_init(w, h)
    info = nogui_native_info(native)
  # Load OpenGL Functions
  if not gladLoadGL(info.glProc):
    log(lvError, "failed load OpenGL")
  # Create Queue, Atlas, Window
  let atlas = newCTXAtlas(result.font.face)
  result.window = newGUIWindow(native, atlas)
  result.state = nogui_native_state(native)
  result.native = native
  result.atlas = atlas
  # Create Shallow String
  result.fmt = addr result.fmt0
  # Copy Default Data
  static: folders: "data" >> ""

template executeApp*(root: GUIWidget, body: untyped) =
  let win {.cursor.} = app.window
  if win.execute(root):
    # TODO: allow configure ms
    loop(16):
      # Handle Events and Execute Body
      if not win.poll(): break
      body; render(win)

# -------------------
# Application Current
# -------------------

proc getApp*(): GUIApplication =
  # Check App Initialize
  when defined(debug):
    if isNil(app.queue):
      log(lvError, "app is not initialized")
  # Return Current App
  result = addr app

proc getWindow*(): GUIClient =
  let win {.cursor.} = getApp().window
  result = cast[GUIClient](win)

# ----------------------------
# Application Class Identifier
# ----------------------------

proc class*(app: GUIApplication, id, name: cstring) =
  app.window.class(id, name)

# ------------------------
# Application Font Metrics
# ------------------------

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
