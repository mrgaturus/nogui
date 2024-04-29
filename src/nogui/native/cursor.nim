import ffi

# -----------------------
# Native Platform Cursors
# -----------------------

{.push header: "native.h".}

type
  GUICursor* {.importc: "nogui_cursor_t *".} = ptr object
  GUICursorSys* {.pure, importc: "nogui_cursorsys_t".} = enum
    cursorArrow
    cursorCross
    cursorMove
    cursorWaitHard
    cursorWaitSoft
    cursorForbidden
    cursorText
    cursorTextUp
    # Hand Cursors
    cursorHandPoint
    cursorHandHover
    cursorHandGrab
    # Zoom Cursors
    cursorZoomIn
    cursorZoomOut
    # Resize Cursors
    cursorSizeVertical
    cursorSizeHorizontal
    cursorSizeDiagLeft
    cursorSizeDiagRight
    # Resize Dock Cursors
    cursorSplitVertical
    cursorSplitHorizontal

{.push importc.}

# GUI Native Cursor
proc nogui_cursor_custom(native: ptr GUINative, bm: GUINativeBitmap): GUICursor
proc nogui_cursor_sys(native: ptr GUINative, id: GUICursorSys): GUICursor
proc nogui_cursor_destroy(native: ptr GUINative, cursor: GUICursor)

# GUI Native Cursor Property
proc nogui_native_cursor(native: ptr GUINative, cursor: GUICursor)
proc nogui_native_cursor_reset(native: ptr GUINative)

{.pop.} # importc
{.pop.} # header

# -------------------
# Native Cursor Lists
# -------------------

type
  GUICursorID* = distinct int32
  GUICursors* = ref object
    native: ptr GUINative
    # Native Cursors Lists
    custom: seq[GUICursor]
    sys: array[GUICursorSys, GUICursor]
    # Current Cursor
    active: GUICursor

proc createCursors*(native: ptr GUINative): GUICursors =
  new result
  # Native Platform
  result.native = native

proc push*(c: var GUICursors, bitmap: GUINativeBitmap) =
  c.custom.add nogui_cursor_custom(c.native, bitmap)

proc destroy*(c: var GUICursors) =
  let native = c.native
  # Destroy Custom Cursors
  for cursor in c.custom:
    if not isNil(cursor):
      nogui_cursor_destroy(native, cursor)
  # Destroy Sys Cursors
  for cursor in c.sys:
    if not isNil(cursor):
      nogui_cursor_destroy(native, cursor)

# ---------------------
# Native Cursor Manager
# ---------------------

proc change(c: var GUICursors, cursor: GUICursor) =
  if cursor != c.active:
    nogui_native_cursor(c.native, cursor)
    c.active = cursor

proc change*(c: var GUICursors, id: GUICursorSys) =
  let native = c.native
  var cursor = c.sys[id]
  # Define Cursor if not Defined
  if isNil(cursor):
    cursor = nogui_cursor_sys(native, id)
    c.sys[id] = cursor
  # Change Current Cursor
  c.change(cursor)

proc change*(c: var GUICursors, id: GUICursorID) =
  let cursor = c.custom[int32 id]
  # Change Current Cursor
  c.change(cursor)

proc reset*(c: var GUICursors) =
  if isNil(c.active): return
  nogui_native_cursor_reset(c.native)
  # Remove Active Cursor
  c.active = nil
