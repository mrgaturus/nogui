import widget, tree, signal, render, timer, manager
from atlas import CTXAtlas
# Native Platform
import ../native/ffi

type
  GUIWindow* = ref object
    native: ptr GUINative
    timers: ptr GUITimers
    # Window Manager
    ctx: CTXRender
    man: GUIManager
    # Window Running
    running: bool

# -------------------------
# Window Native Queue Procs
# -------------------------

proc procSignal(win: GUIWindow, signal: GUISignal)
proc procEvent(win: GUIWindow, signal: pointer)

proc useQueue(win: GUIWindow, native: ptr GUINative) =
  let
    self = cast[pointer](win)
    queue = nogui_native_queue(native)
  var cbEvent, cbSignal: GUINativeCallback
  # Define Native Callbacks
  cbEvent.fn = cast[GUINativeProc](procEvent)
  cbSignal.fn = cast[GUINativeProc](procSignal)
  cbEvent.self = self
  cbSignal.self = self
  # Prepare Native Callbacks
  queue.cb_event = cbEvent
  queue.cb_signal = cbSignal
  # Prepare Signal Queue
  signal.useQueue(queue)

# ---------------------
# Window Creation Procs
# ---------------------

proc newGUIWindow*(native: ptr GUINative, atlas: CTXAtlas): GUIWindow =
  new result
  # Define Window Native
  result.native = native
  result.timers = useTimers()
  result.man = useManager(native)
  # Define Window Queue
  result.useQueue(native)
  result.ctx = newCTXRender(atlas)

proc execute*(win: GUIWindow, root: GUIWidget): bool =
  win.man.root = root
  root.kind = wkRoot
  root.flags.incl(wVisible)
  # Set to Global Dimensions
  let info = nogui_native_info(win.native)
  root.metrics.w = int16 info.width
  root.metrics.h = int16 info.height
  # Open Program Native Window
  result = nogui_native_open(win.native) != 0
  win.running = result
  # Set Renderer Viewport Dimensions
  viewport(win.ctx, info.width, info.height)
  relax(root.target, wsLayout)

# ------------------
# Window Queue Procs
# ------------------

proc procEvent(win: GUIWindow, signal: pointer) =
  let 
    state = nogui_native_state(win.native)
    man {.cursor.} = win.man
  # Process Event State
  case state.kind
  of evUnknown: discard
  # Window Manager Events
  of evCursorMove, evCursorClick, evCursorRelease:
    man.cursorEvent(state)
  of evKeyDown, evKeyUp, evFocusNext, evFocusPrev:
    if not man.keyEvent(state):
      # TODO: callback hotkeys
      echo state.key.name()
  # Window Property Events
  of evWindowExpose: discard
  of evWindowClose:
    win.running = false
  of evWindowResize:
    let
      info = nogui_native_info(win.native)
      metrics = addr man.root.metrics
    # Change Root Dimensions
    metrics.w = int16 info.width
    metrics.h = int16 info.height
    # Update Root Layout
    viewport(win.ctx, info.width, info.height)
    relax(man.root, wsLayout)
  # Window Hover Events
  of evWindowEnter, evWindowLeave:
    return

proc procSignal(win: GUIWindow, signal: GUISignal) =
  case signal.kind
  of sCallback, sCallbackEX:
    signal.call()
  of sWidget:
    let
      widget = cast[GUIWidget](signal.target)
      man {.cursor.} = win.man
    case signal.ws
    of wsLayout: layout(man, widget)
    of wsFocus: focus(man, widget)
    # Window Layer Widget
    of wsOpen: open(man, widget)
    of wsClose: close(man, widget)

# -------------------
# GUI Rendering Procs
# -------------------

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
