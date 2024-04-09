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
    evFlush
    evPending
    # Cursor Events
    evCursorMove
    evCursorClick
    evCursorRelease
    # Key Events
    evKeyDown
    evKeyUp
    evNextFocus
    evPrevFocus
    # Window Events
    evWindowExpose
    evWindowResize
    evWindowEnter
    evWindowLeave
    evWindowClose
  # GUI Native State Object
  GUINative* {.importc: "nogui_native_t".} = object
  GUIState* {.importc: "nogui_state_t".} = object
    native: ptr GUINative
    queue*, cherry*: ptr pointer
    # Kind State
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
    utf8status*: int32
    utf8cap, utf8size*: int32
    utf8str*: cstring

type
  # GUI Native Properties
  GUINativeCursor* {.importc: "nogui_cursor_t".} = object
  GUINativeInfo* {.importc: "nogui_info_t".} = object
    title*: cstring
    width*, height*: int32
    cursor*: ptr GUINativeCursor
    # OpenGL Function Loader
    gl_major*, gl_minor*: int32
    gl_loader*: proc (name: cstring): pointer {.noconv.}

{.push importc.}

# GUI Native Object
proc nogui_native_init*(w, h: int32): ptr GUINative
proc nogui_native_execute*(native: ptr GUINative): int32
proc nogui_native_frame*(native: ptr GUINative)
proc nogui_native_info*(native: ptr GUINative): ptr GUINativeInfo
proc nogui_native_destroy*(native: ptr GUINative)

# GUI Native Event
proc nogui_native_state*(native: ptr GUINative): ptr GUIState
proc nogui_state_poll*(state: ptr GUIState)
proc nogui_state_next*(state: ptr GUIState): int32

# GUI Native Properties
proc nogui_window_title*(native: ptr GUINative, title: cstring)
proc nogui_window_cursor*(native: ptr GUINative, cursor: GUINativeCursor)

{.pop.} # importc
{.pop.} # header

proc mods*(state: ptr GUIState): GUIKeymods {.inline.} =
  cast[GUIKeymods](state.mask)

# ------------------------
# Platform Native Compiler
# ------------------------

# Linux / X11
# BSD is not supported
# Wayland has awful governance
when defined(linux):
  {.passL: "-lX11 -lXi -lEGL".}
  # Compile X11 Native Platform
  {.compile: "x11/cursor.c".}
  {.compile: "x11/device.c".}
  {.compile: "x11/event.c".}
  {.compile: "x11/keymap.c".}
  {.compile: "x11/window.c".}
