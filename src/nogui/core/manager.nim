import ../native/ffi
import widget, tree, callback

type
  GUILayer* = object
    first*: GUIWidget
    last* {.cursor.}: GUIWidget
  GUIForward = object
    hover {.cursor.}: GUIWidget
    jump {.cursor.}: GUIWidget
  # GUI Window Manager
  GUIManager* = ref object
    state: ptr GUIState
    # Window Event Forward
    cbForward: GUICallbackEX[GUIWidget]
    cbLand: GUICallback
    # Window Frames
    root*: GUIWidget
    frame*: GUILayer
    popup*: GUILayer
    tooltip*: GUILayer
    # Window Event State
    focus {.cursor.}: GUIWidget
    stack: seq[GUIForward]
    depth, stops: int

# --------------------
# Layer Attach Manager
# --------------------

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

# ----------------------
# Keyboard Focus Manager
# ----------------------

proc unfocus*(man: GUIManager) =
  let focus {.cursor.} = man.focus
  # Handle Focus Out
  if not isNil(focus):
    focus.flags.excl(wFocus)
    focus.vtable.handle(focus, outFocus)
  # Remove Focus
  man.focus = nil

proc focus*(man: GUIManager, widget: GUIWidget) =
  # Check if is able to be Focused
  if widget == man.focus or
  not widget.focusable():
    return
  # Remove Previous Focus
  man.unfocus()
  # Handle Focus In
  widget.flags.incl(wFocus)
  widget.vtable.handle(widget, inFocus)
  # Replace Focus
  man.focus = widget

proc step*(man: GUIManager, back: bool) =
  let pivot {.cursor.} = man.focus
  # Avoid Step Empty Focus
  if isNil(pivot):
    return
  # Step Focus Widget
  var widget {.cursor.} = pivot
  widget = step(pivot, back)
  # Change Focused
  if widget != pivot:
    man.unfocus()
    # Handle Focus In
    widget.flags.incl(wFocus)
    widget.vtable.handle(widget, inFocus)
    # Replace Focus
    man.focus = widget

# --------------------
# Layer Layout Manager
# --------------------

proc layer(man: GUIManager, widget: GUIWidget): ptr GUILayer =
  case widget.kind
  of wkFrame: addr man.frame
  of wkPopup: addr man.popup
  of wkTooltip: addr man.tooltip
  # Not Belongs to Layer
  else: nil

proc open*(man: GUIManager, widget: GUIWidget) =
  if wVisible in widget.flags: return
  # Attach Widget to Layer
  let la = man.layer(widget)
  if isNil(la): return
  la[].attach(widget)
  # Handle Widget Attach
  widget.flags.incl(wVisible)
  widget.vtable.handle(widget, inFrame)
  widget.arrange()

proc close*(man: GUIManager, widget: GUIWidget) =
  let la = man.layer(widget)
  if isNil(la): return
  la[].detach(widget)
  # Remove Focus if is Inside
  let focus {.cursor.} = man.focus
  if not isNil(focus) and focus.outside() == widget:
    man.unfocus()
  # Handle Widget Detach
  widget.flags.excl(wVisible)
  widget.vtable.handle(widget, outFrame)

proc layout*(man: GUIManager, widget: GUIWidget) =
  if wVisible in widget.flags:
    widget.arrange()
    # Check if Focus is Lost
    let focus {.cursor.} = man.focus
    if not isNil(focus) and not widget.focusable():
      man.unfocus()

# --------------------
# Cursor Hover Manager
# --------------------

proc unhover(man: GUIManager, idx: int) =
  let hover = man.stack[idx].hover
  hover.flags.excl(wHover)
  hover.vtable.handle(hover, outHover)

proc unhover*(man: GUIManager) =
  var i = high(man.stack)
  # Handle Focus Out
  while i >= 0:
    man.unhover(i)
    # Next Hover
    dec(i)
  # Clear Hover Stack
  setLen(man.stack, 0)
  man.depth = 0

proc land(man: GUIManager) =
  let depth = man.depth
  var i = high(man.stack)
  # Handle Focus Out
  while i >= depth:
    man.unhover(i)
    # Next Hover
    dec(i)
  # Land Hover Stack
  setLen(man.stack, depth)

proc hover*(man: GUIManager, widget: GUIWidget) =
  let i = man.depth
  man.depth = i + 1
  # Push to Hover Stack
  if i + 1 > len(man.stack):
    setLen(man.stack, i + 1)
  # Collapse Hover Stack
  elif widget != man.stack[i].hover:
    man.land()
    man.unhover(i)
    man.stack[i] = default(GUIForward)
  else: return
  # Handle Hover In
  widget.flags.incl(wHover)
  widget.vtable.handle(widget, inHover)
  man.stack[i].hover = widget

# ----------------------
# Cursor Forward Manager
# ----------------------

proc cursorOuter(man: GUIManager, x, y: int32): GUIWidget =
  if len(man.stack) > 0:
    let outer = man.stack[0].hover
    # Return Grabbed Outermost
    if wGrab in outer.flags:
      return outer
  # Find Last Popup
  if not isNil(man.popup.last):
    result = man.popup.last
  # Find Hovered Frame
  elif not isNil(man.frame.last):
    for widget in reverse(man.frame.last):
      if pointOnArea(widget, x, y):
        result = widget
        break
  # Fallback to Root
  if isNil(result):
    result = man.root

proc cursorGrab(widget: GUIWidget, state: ptr GUIState) =
  var flags = widget.flags
  let popup = widget.kind == wkPopup
  # Change Widget Grab
  if state.kind == evCursorClick:
    flags.incl(wGrab)
  elif state.kind == evCursorRelease:
    flags.excl(wGrab)
  # Check Widget Hover on Grab or Popup
  if wGrab in (flags + widget.flags) or popup:
    let check = widget.pointOnArea(state.mx, state.my)
    if check: flags.incl(wHover)
    else: flags.excl(wHover)
    # Handle Hover Changed on Popup Toplevel
    if popup and check != (wHover in widget.flags):
      let handle = widget.vtable.handle
      if check: handle(widget, inHover)
      else: handle(widget, outHover)
  # Replace Widget Flags
  widget.flags = flags

proc cursorForward(man: GUIManager, widget: GUIWidget) =
  let
    state = man.state
    depth = man.depth
    flags = widget.flags
  # Configure Cursor Hover
  man.hover(widget)
  widget.cursorGrab(state)
  # Dispatch Cursor Event
  if wMouse in flags:
    widget.vtable.event(widget, state)
  # Forward Whole Stack if was Grabbed
  if wGrab in (flags + widget.flags):
    if depth < high(man.stack):
      let next = man.stack[depth + 1].hover
      send(man.cbForward, next)
  # Forward to Next Inside Widget
  elif widget.kind >= wkRoot or widget.kind == wkForward:
    let jump = addr man.stack[depth].jump
    # Prepare Next Pivot
    var next {.cursor.} = jump[]
    if isNil(next):
      next = widget
    # Find Next Widget and Store Cache
    next = next.find(state.mx, state.my)
    jump[] = next.parent
    # Forward Event
    if next != widget:
      send(man.cbForward, next)
    else: send(man.cbLand)
  # Finalize Event Forwarding
  else: send(man.cbLand)

# ----------------------
# Event Dispatch Manager
# ----------------------

proc cursorEvent*(man: GUIManager, state: ptr GUIState) =
  let outer = man.cursorOuter(state.mx, state.my)
  # Prepare Cursor Event
  man.state = state
  man.depth = 0
  man.stops = 0
  # Elevate Outer Frame when Clicked
  if state.kind == evCursorClick and outer.kind == wkFrame:
    elevate(man.frame, outer)
  # Dispatch Cursor Event
  man.cursorForward(outer)

proc keyEvent*(man: GUIManager, state: ptr GUIState): bool =
  let
    pivot {.cursor.} = man.focus
    next = state.kind == evFocusNext
    back = state.kind == evFocusPrev
  # No Focused Widget
  if isNil(pivot):
    return false
  elif not (next or back):
    result = wKeyboard in pivot.flags
    if result: pivot.vtable.event(pivot, state)
  else: # Focus Cycle Tab
    man.step(back)
    result = true

# ------------------------
# Event Forwarding Manager
# ------------------------

proc forward*(man: GUIManager, widget: GUIWidget) =
  let state = man.state
  case state.kind
  # Forward Cursor Event
  of evCursorClick, evCursorMove, evCursorRelease:
    var w {.cursor.} = widget
    if w.kind in {wkLayout, wkContainer}:
      w = w.find(state.mx, state.my)
    # Dispatch Forward if not Grabbed
    let outer {.cursor.} = man.stack[0].hover
    if wGrab notin outer.flags and state.kind != evCursorRelease:
      man.cursorForward(w)
  # Forward Key Event
  of evKeyDown, evKeyUp:
    if wKeyboard in widget.flags:
      widget.vtable.event(widget, state)
  # Skip Invalid Event
  else: discard

proc stop*(man: GUIManager, widget: GUIWidget) =
  let
    depth = man.depth - 1
    check = depth >= 0 and
      man.stack[depth].hover == widget
  # Check if Widget is Current Hover
  man.stops += int(check)
  if man.stops == 1:
    man.land()

# -----------------------
# Event Configure Manager
# -----------------------

proc onforward(man: GUIManager, widget: ptr GUIWidget) =
  if man.stops == 0:
    man.cursorForward widget[]

proc onland(man: GUIManager) =
  if man.stops == 0:
    man.land()

proc createManager*(): GUIManager =
  new result
  # Register Forward Callback
  let self = cast[pointer](result)
  result.cbForward = unsafeCallbackEX[GUIWidget](self, onforward)
  result.cbLand = unsafeCallback(self, onland)
  # Create Forward Stack
  result.stack = newSeqOfCap[GUIForward](8)
