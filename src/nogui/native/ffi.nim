# Avoid import os.parentDir
proc includePath(): string {.compileTime.} =
  result = currentSourcePath()
  var l = result.len
  # Remove File Name
  while l > 0:
    let c = result[l - 1]
    if c == '/' or c == '\\':
      break
    # Next Char
    dec(l)
  # Remove Chars
  result.setLen(l)
  
# Include Native Folder
{.passC: "-I" & includePath().}
{.compile: "logger.c".}
{.compile: "queue.c".}
{.compile: "time.c".}

{.push header: "native.h".}
# Export Keymap Objects
import keymap
export keymap

type
  # GUI State Enums
  GUITool* {.pure, importc: "nogui_tool_t".} = enum
    devStylus
    devEraser
    devMouse
  GUIEvent* {.pure, importc: "nogui_event_t".} = enum
    evUnknown
    # Cursor Events
    evCursorMove
    evCursorClick
    evCursorRelease
    # Key Events
    evKeyDown
    evKeyUp
    evFocusNext
    evFocusPrev
    # Window Events
    evWindowExpose
    evWindowResize
    evWindowEnter
    evWindowLeave
    evWindowClose
  # GUI Native State Object
  GUINative* {.importc: "nogui_native_t".} = object
  GUIState* {.importc: "nogui_state_t".} = object
    kind*: GUIEvent
    tool*: GUITool
    # Cursor State
    mx*, my*: int32
    px*, py*: float32
    pressure*: float32
    # Keyboard State
    key*: GUIKeycode
    mask: GUIKeymask
    scan*: uint32
    # Input Method Dummy
    # TODO: first class IME support
    utf8state*: int32
    utf8cap, utf8size*: int32
    utf8str*: cstring

type
  # GUI Native Bitmap 4bytes
  GUINativeBitmap* {.importc: "nogui_bitmap_t".} = object
    w*, h*: int32
    ox*, oy*: int32
    # Buffer Pixels RGBA
    pixels*: ptr uint8
  # GUI Native Properties
  GUINativeTime* {.importc: "nogui_time_t".} = distinct int64
  GUINativeInfo* {.importc: "nogui_info_t".} = object
    title*: cstring
    id*, name*: cstring
    width*, height*: int32
    # OpenGL Function Loader
    glMajor*, glMinor*: int32
    glProc*: proc (name: cstring): pointer {.noconv.}
  # GUI Native Callback
  GUINativeProc* {.importc: "nogui_proc_t".} =
    proc(self, data: pointer) {.noconv.}
  GUINativeCallback* {.importc: "nogui_cb_t".} = object
    self*: pointer
    fn*: GUINativeProc
  # GUI Native Queue
  GUINativeQueue* {.importc: "nogui_queue_t".} = object
    cb_event*: GUINativeCallback

{.push importc.}

proc nogui_time_now*(): GUINativeTime
proc nogui_time_ms*(ms: cint): GUINativeTime
proc nogui_time_sleep*(time: GUINativeTime)

# ----------------------
# GUI Native Queue Procs
# ----------------------

# GUI Native Queue Callback
proc nogui_cb_create*(bytes: int32): ptr GUINativeCallback
proc nogui_cb_data*(cb: ptr GUINativeCallback): pointer
proc nogui_cb_call*(cb: ptr GUINativeCallback)

# GUI Native Queue Push
proc nogui_queue_push*(queue: ptr GUINativeQueue, cb: ptr GUINativeCallback)
proc nogui_queue_relax*(queue: ptr GUINativeQueue, cb: ptr GUINativeCallback)

# -------------------------
# GUI Native Platform Procs
# -------------------------

# GUI Native Platform
proc nogui_native_init*(w, h: int32): ptr GUINative
proc nogui_native_open*(native: ptr GUINative): int32
proc nogui_native_frame*(native: ptr GUINative)
proc nogui_native_destroy*(native: ptr GUINative)

# GUI Native Objects
proc nogui_native_info*(native: ptr GUINative): ptr GUINativeInfo
proc nogui_native_queue*(native: ptr GUINative): ptr GUINativeQueue
proc nogui_native_state*(native: ptr GUINative): ptr GUIState

# GUI Native Identifier Property
proc nogui_native_id*(native: ptr GUINative, id, name: cstring)
proc nogui_native_title*(native: ptr GUINative, title: cstring)

# GUI Native Event Pooling
proc nogui_native_pump*(native: ptr GUINative)
proc nogui_native_poll*(native: ptr GUINative): int32

{.pop.} # importc
{.pop.} # header

proc mods*(state: ptr GUIState): GUIKeymods {.inline.} =
  cast[GUIKeymods](state.mask)

proc `+`*(a, b: GUINativeTime): GUINativeTime {.borrow.}
proc `-`*(a, b: GUINativeTime): GUINativeTime {.borrow.}
proc `<`*(a, b: GUINativeTime): bool {.borrow.}

# ------------------------
# Platform Native Compiler
# ------------------------

# Linux / X11
# BSD is not supported
# Wayland has awful governance
when defined(linux):
  {.passL: "-lX11 -lXi -lXcursor -lEGL".}
  # Compile X11 Native Platform
  {.compile: "x11/device.c".}
  {.compile: "x11/event.c".}
  {.compile: "x11/keymap.c".}
  {.compile: "x11/props.c".}
  {.compile: "x11/window.c".}

# Windows Win32
# MSYS2 + Mingw64 Platform
when defined(windows):
  {.passL: "-lopengl32 -lgdi32".}
  # Compile Win32 Native Platform
  {.compile: "win32/device.c".}
  {.compile: "win32/event.c".}
  {.compile: "win32/keymap.c".}
  {.compile: "win32/props.c".}
  {.compile: "win32/window.c".}
