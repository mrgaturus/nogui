import widget, callback, render, timer, manager, shortcut
from tree import render
from atlas import CTXAtlas
# GUI Native Platform
import ../native/[ffi, cursor]

type
  WindowMessage* = enum
    wsUnFocus
    wsUnHover
    wsUnGrab
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
    cursors: GUICursors
    # Window Renderer
    ctx: CTXRender
    man: GUIManager
    shorts: GUIShortcuts
    observers: GUIObservers
    # Window Callbacks Messenger
    cbWidget: GUICallbackEX[WidgetSignal]
    cbWindow: GUICallbackEX[WindowMessage]
    # Window Running
    lazy: int32
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

# -------------------------
# Window Client Information
# -------------------------

proc title*(win: GUIClient, name: cstring) =
  nogui_native_title(win.native, name)

proc class*(win: GUIWindow, id, name: cstring) =
  nogui_native_id(win.native, id, name)

proc rect*(win: GUIClient): GUIRect =
  let info = nogui_native_info(win.native)
  result.w = info.width
  result.h = info.height

# -----------------------
# Window Client Shortcuts
# -----------------------

proc shorts*(win: GUIClient): ptr GUIShortcuts =
  addr win.shorts

proc observers*(win: GUIClient): ptr GUIObservers =
  addr win.observers

# ---------------------
# Window Client Cursors
# ---------------------

proc cursor*(win: GUIClient, id: GUICursorSys) =
  win.cursors.change(id)

proc cursor*(win: GUIClient, id: GUICursorID) =
  win.cursors.change(id)

proc cursorReset*(win: GUIClient) =
  win.cursors.reset()

# -----------------------
# Window Client Rendering
# -----------------------

proc exposed*(win: GUIClient): bool {.inline.} =
  win.lazy != 0

proc fuse*(win: GUIClient) {.inline.} =
  inc(win.lazy)

proc defuse*(win: GUIClient) {.inline.} =
  dec(win.lazy)

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
  # Lazy Rendering
  inc(win.lazy)

proc procWindow(win: GUIWindow, msg: ptr WindowMessage) =
  let man {.cursor.} = win.man
  # Dispatch Window Signal
  case msg[]
  of wsUnFocus: man.unfocus()
  of wsUnHover: man.unhover()
  of wsUnGrab: man.ungrab()
  of wsUnHold: man.unhold()
  of wsTerminate:
    win.running = false
  # TODO: Window Buttons
  else: discard
  # Lazy Rendering
  inc(win.lazy)

proc procEvent(win: GUIWindow, msg: pointer) =
  let 
    state = nogui_native_state(win.native)
    man {.cursor.} = win.man
  # Dispatch Event Observers
  dispatch(win.observers, state)
  # Dispatch Event
  case state.kind
  of evUnknown: discard
  # Window Manager Events
  of evCursorMove, evCursorClick, evCursorRelease:
    man.cursorEvent(state)
  of evKeyDown, evKeyUp, evFocusNext, evFocusPrev:
    if state.key == NK_Unknown: return
    if not man.keyEvent(state):
      dispatch(win.shorts, state)
  # Window Property Events
  of evWindowExpose:
    win.lazy = 65535
  of evWindowClose:
    # TODO: close callback
    win.running = false
  of evWindowResize:
    let info = nogui_native_info(win.native)
    win.resize(info.width, info.height)
  # Window Hover Events
  of evWindowEnter, evWindowLeave:
    return
  # Lazy Rendering
  inc(win.lazy)

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
  result.cursors = createCursors(native)
  # Define Window Manager
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
  let
    ctx = addr win.ctx
    man {.cursor.} = win.man
  # Reset Lazy Rendering
  if win.lazy == 0: return
  win.lazy = 0
  # Begin Rendering
  begin(win.ctx)
  # Render Root
  render(man.root, ctx)
  ctx[].render()
  # Render Window Layers
  ctx.renderLayer(man.frame)
  ctx.renderLayer(man.popup)
  ctx.renderLayer(man.tooltip)
  # End Rendering
  finish()
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
