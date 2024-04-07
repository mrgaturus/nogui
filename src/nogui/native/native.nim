{.compile: "logger.c".}
{.push header: "nogui/native/native.h".}

type
  # GUI State Enums
  GUITool* {.pure, importc: "nogui_tool_t".} = enum
    devStylus
    devEraser
    devMouse
  GUIEvent* {.pure, importc: "nogui_event_t".} = enum
    evInvalid
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
    evWindowLeave
    evWindowClose
  # GUI Native State Object
  GUINative* {.importc: "nogui_native_t".} = object
  GUIState* {.importc: "nogui_state_t".} = object
    native: ptr GUINative
    # Kind State
    kind*: GUIEvent
    tool*: GUITool
    # Cursor State
    mx*, my*: int32
    px*, py*: float32
    pressure*: float32
    # Key State
    key*: uint32
    mods*: uint32
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
proc nogui_native_execute*(native: ptr GUINative)
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

# Linux / X11
# BSD is not supported
# Wayland has awful governance
when defined(linux):
  {.passL: "-lX11 -lEGL".}
  # Compile X11 Native Platform
  {.compile: "x11/cursor.c".}
  {.compile: "x11/device.c".}
  {.compile: "x11/event.c".}
  {.compile: "x11/window.c".}
