import widget, tree, signal, render, timer
from atlas import CTXAtlas
# Native Platform
import ../native/ffi

type
  GUILayer = object
    first: GUIWidget
    last {.cursor.}: GUIWidget
  GUIWindow* = ref object
    native: ptr GUINative
    timers: ptr GUITimers
    ctx: CTXRender
    # Window Root
    root: GUIWidget
    # Window Layers
    frame: GUILayer
    popup: GUILayer
    tooltip: GUILayer
    # Status Widgets
    focus: GUIWidget
    hover: GUIWidget
    # Status Execution
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
  # Define Window Queue
  result.useQueue(native)
  result.ctx = newCTXRender(atlas)

proc execute*(win: GUIWindow, root: GUIWidget): bool =
  win.root = root
  # Define Root Properties
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

# --------------------------
# Window Layer Attach/Detach
# --------------------------

proc attach(layer: var GUILayer, widget: GUIWidget) =
  if isNil(layer.last):
    layer.first = widget
    layer.last = widget
    # Remove Endpoints
    widget.next = nil
    widget.prev = nil
    widget.parent = nil
  else: # Attach Last
    attachNext(layer.last, widget)
    layer.last = widget

proc detach(layer: var GUILayer, widget: GUIWidget) =
  # Replace First or Last
  if widget == layer.first:
    layer.first = widget.next
  if widget == layer.last:
    layer.last = widget.prev
  # Detach Widget
  widget.detach()
  # Remove Endpoints
  widget.next = nil
  widget.prev = nil

proc elevate(layer: var GUILayer, widget: GUIWidget) =
  # Nothing to Elevate
  if widget == layer.last:
    return
  # Replace First
  if widget == layer.first:
    layer.first = widget.next
  # Detach Widget
  widget.detach()
  # Attach to Last
  attachNext(layer.last, widget)
  layer.last = widget

proc layer(win: GUIWindow, widget: GUIWidget): ptr GUILayer =
  case widget.kind
  of wkFrame: addr win.frame
  of wkPopup: addr win.popup
  of wkTooltip: addr win.tooltip
  # Not Belongs to Layer
  else: nil

# ---------------------
# Window Status Manager
# ---------------------

proc unhover(win: GUIWindow) =
  let hover {.cursor.} = win.hover
  # Handle Focus Out
  if not isNil(hover):
    hover.flags.excl(wHover)
    hover.vtable.handle(hover, outHover)
  # Remove Focus
  win.hover = nil

proc unfocus(win: GUIWindow) =
  let focus {.cursor.} = win.focus
  # Handle Focus Out
  if not isNil(focus):
    focus.flags.excl(wFocus)
    focus.vtable.handle(focus, outFocus)
  # Remove Focus
  win.focus = nil

proc focus(win: GUIWindow, widget: GUIWidget) =
  # Check if is able to be Focused
  if widget == win.focus or
  not widget.focusable():
    return
  # Remove Previous Focus
  win.unfocus()
  # Handle Focus In
  widget.flags.incl(wFocus)
  widget.vtable.handle(widget, inFocus)
  # Replace Focus
  win.focus = widget

# ---------------------
# Window Layout Manager
# ---------------------

proc open(win: GUIWindow, widget: GUIWidget) =
  if wVisible in widget.flags: return
  # Attach Widget to Layer
  let la = win.layer(widget)
  la[].attach(widget)
  # Handle Widget Attach
  widget.flags.incl(wVisible)
  widget.vtable.handle(widget, inFrame)
  widget.arrange()

proc close(win: GUIWindow, widget: GUIWidget) =
  let la = win.layer(widget)
  la[].detach(widget)
  # Remove Focus if is Inside
  let focus {.cursor.} = win.focus
  if not isNil(focus) and focus.outside() == widget:
    win.unfocus()
  # Handle Widget Detach
  widget.flags.excl(wVisible)
  widget.vtable.handle(widget, outFrame)

proc layout(win: GUIWindow, widget: GUIWidget) =
  if wVisible in widget.flags:
    widget.arrange()
    # Check if Focus is Lost
    let focus {.cursor.} = win.focus
    if not isNil(focus) and not widget.focusable():
      win.unfocus()

# --------------------------
# Window Event Widget Finder
# --------------------------

proc findFocus(win: GUIWindow, state: ptr GUIState): GUIWidget =
  let
    focus {.cursor.} = win.focus
    next = state.kind == evFocusNext
    back = state.kind == evFocusPrev
  # Check if not has focus or is not cycle
  if not (next or back) or isNil(focus):
    return focus
  # Step Focus Widget
  var widget {.cursor.} = focus
  if not isNil(widget.parent):
    widget = step(widget, back)
    if widget != focus:
      # Handle Focus Out
      focus.flags.excl(wFocus)
      focus.vtable.handle(focus, outFocus)
      # Handle Focus In
      widget.flags.incl(wFocus)
      widget.vtable.handle(widget, inFocus)
      # Change Focus
      win.focus = widget
  # Change Current Focus
  result = win.focus

proc findHover(win: GUIWindow, state: ptr GUIState): GUIWidget =
  if not isNil(win.hover) and wGrab in win.hover.flags:
    return win.hover
  # Find Last Popup
  elif not isNil(win.popup.last):
    result = win.popup.last
  # Find Frames
  elif not isNil(win.frame.last):
    for widget in reverse(win.frame.last):
      if pointOnArea(widget, state.mx, state.my):
        result = widget
        break # Frame Found
  # Fallback to Root
  if isNil(result):
    result = win.root
  # Find at the Outermost if Hover is not inside
  var pivot {.cursor.} = win.hover
  if isNil(pivot) or pivot.outside() != result:
    pivot = result
  # Find Inside Widget
  result = pivot.find(state.mx, state.my)

# --------------------
# Window Event Prepare
# --------------------

proc prepareHover(win: GUIWindow, found: GUIWidget, state: ptr GUIState) =
  if (wGrab in found.flags) or found.kind == wkPopup:
    # Mark if is Inside Widget
    if found.pointOnArea(state.mx, state.my):
      found.flags.incl(wHover)
    else: found.flags.excl(wHover)
  # Prepare Widget Hover
  if found != win.hover:
    win.unhover()
    # Handle Change Hover
    found.flags.incl(wHover)
    found.vtable.handle(found, inHover)
    # Change Previous Hover
    win.hover = found

proc prepareClick(win: GUIWindow, found: GUIWidget, state: ptr GUIState) =
  let kind = state.kind
  if kind == evCursorClick:
    found.flags.incl(wGrab)
    # Elevate if is a Frame
    let frame = found.outside()
    if frame.kind == wkFrame:
      elevate(win.frame, frame)
  # Remove Widget Grab
  elif kind == evCursorRelease:
    found.flags.excl(wGrab)

# ---------------------------
# Window Event Dispatch Procs
# ---------------------------

proc widgetEvent(win: GUIWindow, state: ptr GUIState) =
  var
    enabled: bool
    found {.cursor.}: GUIWidget
  case state.kind
  # Cursor Event Dispatch
  of evCursorMove, evCursorClick, evCursorRelease:
    found = win.findHover(state)
    win.prepareHover(found, state)
    # Check if widget is Enabled
    enabled = wMouse in found.flags
    # Prepare Widget Grab
    if enabled:
      win.prepareClick(found, state)
  # Keyboard Event Dispatch
  of evKeyDown, evKeyUp, evFocusNext, evFocusPrev:
    let prev = win.focus
    found = win.findFocus(state)
    # TODO: dispatch callback based hotkeys instead root
    if isNil(found):
      return
    elif found != prev:
      return
    # Check if widget is Enabled
    enabled = wKeyboard in found.flags
  # No Event Found
  else: discard
  # Dispatch Widget Event
  if enabled:
    found.vtable.event(found, state)

# ------------------
# Window Queue Procs
# ------------------

proc procEvent(win: GUIWindow, signal: pointer) =
  let state = nogui_native_state(win.native)
  # Process Event State
  case state.kind
  of evUnknown: discard
  of evWindowExpose: discard
  of evWindowClose:
    win.running = false
  of evWindowResize:
    let
      info = nogui_native_info(win.native)
      metrics = addr win.root.metrics
    # Change Root Dimensions
    metrics.w = int16 info.width
    metrics.h = int16 info.height
    # Update Root Layout
    viewport(win.ctx, info.width, info.height)
    relax(win.root, wsLayout)
  # Window Hover Events
  of evWindowEnter, evWindowLeave:
    return
  # Widget Events
  else: win.widgetEvent(state)

proc procSignal(win: GUIWindow, signal: GUISignal) =
  case signal.kind
  of sCallback, sCallbackEX:
    signal.call()
  of sWidget:
    let widget =
      cast[GUIWidget](signal.target)
    case signal.ws
    of wsLayout: layout(win, widget)
    of wsFocus: focus(win, widget)
    # Window Layer Widget
    of wsOpen: open(win, widget)
    of wsClose: close(win, widget)

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
  let ctx = addr win.ctx
  # Render Root
  render(win.root, ctx)
  ctx[].render()
  # Render Window Layers
  ctx.renderLayer(win.frame)
  ctx.renderLayer(win.popup)
  ctx.renderLayer(win.tooltip)
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
