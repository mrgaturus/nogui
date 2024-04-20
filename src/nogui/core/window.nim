import widget, callback, render, timer, manager
from tree import render
from atlas import CTXAtlas
# Native Platform
import ../native/ffi

type
  WindowMessage* = enum
    wsUnFocus
    wsUnHover
    wsUnHold
    # Window Buttons
    wsMaximize
    wsMininize
    wsClose
    # Window Exit
    wsTerminate
  WidgetMessage* = enum
    wsFocus
    wsLayout
    wsForward
    wsStop
    # Toplevel
    wsOpen
    wsClose
    wsHold
  WidgetSignal = object
    msg: WidgetMessage
    widget {.cursor.}: GUIWidget

type
  Window = object
    native: ptr GUINative
    timers: ptr GUITimers
    # Window Renderer
    ctx: CTXRender
    man: GUIManager
    # Window Callbacks Messenger
    cbWidget: GUICallbackEX[WidgetSignal]
    cbWindow: GUICallbackEX[WindowMessage]
    # Window Running
    running: bool
  # GUI Window Client
  GUIWindow* = ref Window
  GUIClient* = ptr Window

# -----------------------
# Window Client Messenger
# -----------------------

proc send*(win: GUIClient, widget: GUIWidget, msg: WidgetMessage) =
  let signal = WidgetSignal(msg: msg, widget: widget)
  send(win.cbWidget, signal)

proc send*(win: GUIClient, msg: WindowMessage) =
  send(win.cbWindow, msg)

proc relax*(win: GUIClient, widget: GUIWidget, msg: WidgetMessage) =
  let signal = WidgetSignal(msg: msg, widget: widget)
  relax(win.cbWidget, signal)

proc relax*(win: GUIClient, msg: WindowMessage) =
  relax(win.cbWindow, msg)

# --------------------------
# Window Client Manipulation
# --------------------------

proc resize(win: GUIWindow, w, h: int32) =
  let
    man {.cursor.} = win.man
    metrics = addr man.root.metrics
  # Change Root Dimensions
  metrics.w = int16 w
  metrics.h = int16 h
  # Update Root Layout
  viewport(win.ctx, w, h)
  let client = cast[GUIClient](win)
  relax(client, man.root, wsLayout)

# ----------------------
# Window Client Dispatch
# ----------------------

proc procWidget(win: GUIWindow, signal: ptr WidgetSignal) =
  let
    widget {.cursor.} = signal.widget
    man {.cursor.} = win.man
  # Dispatch Widget Signal
  case signal.msg
  of wsLayout: layout(man, widget)
  of wsFocus: focus(man, widget)
  of wsForward: forward(man, widget)
  of wsStop: stop(man, widget)
  # Window Manager Open
  of wsOpen: open(man, widget)
  of wsClose: close(man, widget)
  of wsHold: hold(man, widget)

proc procWindow(win: GUIWindow, msg: ptr WindowMessage) =
  let man {.cursor.} = win.man
  # Dispatch Window Signal
  case msg[]
  of wsUnFocus: man.unfocus()
  of wsUnHover: man.unhover()
  of wsUnHold: man.unhold()
  of wsTerminate:
    win.running = false
  # TODO: Window Buttons
  else: discard

proc procEvent(win: GUIWindow, msg: pointer) =
  let 
    state = nogui_native_state(win.native)
    man {.cursor.} = win.man
  # Dispatch Event
  case state.kind
  of evUnknown: discard
  # Window Manager Events
  of evCursorMove, evCursorClick, evCursorRelease:
    man.cursorEvent(state)
  of evKeyDown, evKeyUp, evFocusNext, evFocusPrev:
    # TODO: callback hotkeys
    if not man.keyEvent(state):
      discard
  # Window Property Events
  of evWindowExpose:
    # TODO: interaction counts
    discard
  of evWindowClose:
    # TODO: close callback
    win.running = false
  of evWindowResize:
    let info = nogui_native_info(win.native)
    win.resize(info.width, info.height)
  # Window Hover Events
  of evWindowEnter, evWindowLeave:
    return

# ----------------------
# Window Client Creation
# ----------------------

proc messenger(win: GUIWindow, native: ptr GUINative) =
  let
    self = cast[pointer](win)
    queue = nogui_native_queue(native)
  # Define Event Native Callback
  var cbEvent: GUINativeCallback
  cbEvent.fn = cast[GUINativeProc](procEvent)
  cbEvent.self = self
  # Define Signal Native Callbacks
  win.cbWidget = unsafeCallbackEX[WidgetSignal](self, procWidget)
  win.cbWindow = unsafeCallbackEX[WindowMessage](self, procWindow)
  # Prepare Native Queue
  queue.cb_event = cbEvent
  callback.messenger(native)

proc newGUIWindow*(native: ptr GUINative, atlas: CTXAtlas): GUIWindow =
  new result
  # Define Window Native
  result.native = native
  result.timers = useTimers()
  result.man = createManager()
  # Define Window Queue
  result.messenger(native)
  result.ctx = newCTXRender(atlas)

# -----------------------
# Window Client Execution
# -----------------------

proc execute*(win: GUIWindow, root: GUIWidget): bool =
  win.man.root = root
  root.kind = wkRoot
  root.flags.incl(wVisible)
  # Open Program Native Window
  result = nogui_native_open(win.native) != 0
  win.running = result
  if not result:
    return result
  # Update Root Layout
  let info = nogui_native_info(win.native)
  win.resize(info.width, info.height)

proc renderLayer(ctx: ptr CTXRender, layer: GUILayer) =
  if isNil(layer.first): return
  # Render Widgets
  for w in forward(layer.first):
    w.render(ctx)
    ctx[].render()

proc render*(win: GUIWindow) =
  begin(win.ctx) # -- Begin GUI Rendering
  let
    ctx = addr win.ctx
    man {.cursor.} = win.man
  # Render Root
  render(man.root, ctx)
  ctx[].render()
  # Render Window Layers
  ctx.renderLayer(man.frame)
  ctx.renderLayer(man.popup)
  ctx.renderLayer(man.tooltip)
  finish() # -- End GUI Rendering
  # Present Frame to Native
  nogui_native_frame(win.native)

proc poll*(win: GUIWindow): bool =
  result = win.running
  let native = win.native
  # Pump Native Events
  if not result:
    return result
  # Pump Native Events
  nogui_native_pump(native)
  nogui_timers_pump(win.timers)
  # Poll Native Pumped Events
  while result and nogui_native_poll(native) != 0:
    result = result and win.running
