import widget, signal, render
from atlas import CTXAtlas, createTexture
# Native Platform
import ../native/ffi

type
  GUILayer = object
    first: GUIWidget
    last {.cursor.}: GUIWidget
  GUIWindow* = ref object
    native: ptr GUINative
    queue: GUIQueue
    ctx: CTXRender
    # Window Widgets
    root: GUIWidget
    # Window Layers
    frame: GUILayer
    popup: GUILayer
    tooltip: GUILayer
    # Status Widgets
    focus: GUIWidget
    hover: GUIWidget

# ---------------------
# Window Creation Procs
# ---------------------

proc newGUIWindow*(native: ptr GUINative, queue: GUIQueue, atlas: CTXAtlas): GUIWindow =
  new result
  # Set Attributes
  result.native = native
  result.queue = queue
  # Bind Queue to State
  let
    state = nogui_native_state(native)
    expose = queue.expose()
  state.queue = expose.queue
  state.cherry = expose.cherry
  # Create Graphics Context
  atlas.createTexture()
  result.ctx = newCTXRender(atlas)

proc execute*(win: GUIWindow, root: GUIWidget): bool =
  win.root = root
  # Set as Frame Kind
  root.kind = wgRoot
  root.flags = {wMouse, wKeyboard, wVisible}
  # Set to Global Dimensions
  let info = nogui_native_info(win.native)
  root.metrics.w = int16 info.width
  root.metrics.h = int16 info.height
  # Execute Native Program
  result = nogui_native_execute(win.native) != 0
  # Set Renderer Viewport Dimensions
  viewport(win.ctx, info.width, info.height)
  delay(root.target, wsLayout)

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
  of wgFrame: addr win.frame
  of wgPopup, wgMenu: addr win.popup
  of wgTooltip: addr win.tooltip
  # Not Belongs to Layer
  else: nil

# -------------------------
# Window Signal Event Procs
# -------------------------

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
  # Handle Widget Detach
  widget.flags.excl(wVisible)
  widget.vtable.handle(widget, outFrame)

proc layout(win: GUIWindow, widget: GUIWidget) =
  if wVisible in widget.flags:
    widget.arrange()
    # Check if is still focused
    if widget == win.focus and
    wFocusable + {wFocus} notin widget.flags:
      widget.flags.excl(wFocus)
      widget.vtable.handle(widget, outFocus)
      # Remove Focus
      win.focus = nil

proc focus(win: GUIWindow, widget: GUIWidget) =
  let focus {.cursor.} = win.focus
  if widget != win.root and
  wFocusable in widget.flags and
  widget != focus:
    # Handle Focus Out
    if not isNil(focus):
      focus.flags.excl(wFocus)
      focus.vtable.handle(focus, outFocus)
    # Handle Focus In
    widget.flags.incl(wFocus)
    widget.vtable.handle(widget, inFocus)
    # Replace Focus
    win.focus = widget

proc signalEvent(win: GUIWindow, signal: GUISignal): bool =
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
  of sWindow:
    case signal.msg
    # TODO: first class IME support
    of wsOpenIM: discard
    of wsCloseIM: discard
    of wsFocusOut: # Un Focus
      let focus {.cursor.} = win.focus
      if not isNil(focus):
        focus.flags.excl(wFocus)
        focus.vtable.handle(focus, outFocus)
        # Remove Focus
        win.focus = nil
    of wsHoverOut: # Un Hover
      let hover {.cursor.} = win.hover
      if not isNil(hover):
        hover.flags.excl(wHoverGrab)
        hover.vtable.handle(hover, outHover)
        # Remove Hover
        win.hover = nil
    of wsTerminate: 
      return true

# ---------------------------
# Window Keyboard Event Procs
# ---------------------------

proc findFocus(win: GUIWindow, state: ptr GUIState): GUIWidget =
  let
    focus {.cursor.} = win.focus
    next = state.kind == evNextFocus
    back = state.kind == evPrevFocus
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

# -------------------------
# Window Cursor Event Procs
# -------------------------

proc findHover(win: GUIWindow, state: ptr GUIState): GUIWidget =
  if not isNil(win.hover) and wGrab in win.hover.flags:
    return win.hover
  # Find Last Popup
  elif not isNil(win.popup.last):
    # TODO: event propagation to make implementation better for menus
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

proc prepareHover(win: GUIWindow, found: GUIWidget, state: ptr GUIState) =
  if (wGrab in found.flags) or found.kind in {wgPopup, wgMenu}:
    # Mark if is Inside Widget
    if found.pointOnArea(state.mx, state.my):
      found.flags.incl(wHover)
    else: found.flags.excl(wHover)
    # Hover Prepared
    return
  # Prepare Widget Hover
  let hover {.cursor.} = win.hover
  if found != hover:
    # Handle Remove Hover
    if not isNil(hover):
      hover.flags.excl(wHover)
      hover.vtable.handle(hover, outHover)
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
    if frame.kind == wgFrame:
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
  of evKeyDown, evKeyUp, evNextFocus, evPrevFocus:
    echo state.key
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

proc handleEvents*(win: GUIWindow): bool =
  # Poll Pending Events
  let state = nogui_native_state(win.native)
  nogui_state_poll(state)
  # Process Pending Events
  while nogui_state_next(state) != 0:
    echo state.key
    case state.kind
    of evUnknown: continue
    of evFlush: discard
    of evPending: pending(win.queue)
    # Window Events
    of evWindowExpose: discard
    of evWindowClose:
      # TODO: propose callback when close
      return true
    of evWindowResize:
      let
        info = nogui_native_info(win.native)
        metrics = addr win.root.metrics
      # Change Root Dimensions
      metrics.w = int16 info.width
      metrics.h = int16 info.height
      # Update Root Layout
      viewport(win.ctx, info.width, info.height)
      delay(win.root.target, wsLayout)
    of evWindowEnter, evWindowLeave:
      continue
    else: win.widgetEvent(state)
    # Process Signals
    for signal in poll(win.queue):
      if win.signalEvent(signal):
        return true

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
