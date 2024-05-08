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
    # Window Focus State
    focus {.cursor.}: GUIWidget
    hold {.cursor.}: GUIWidget
    # Window Hover State
    stack: seq[GUIForward]
    backup: seq[GUIForward]
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
# Cursor Hover Manager
# --------------------

proc unhover(man: GUIManager, idx: int) =
  let
    hover = man.stack[idx].hover
    flags = hover.flags
  # Remove Grab
  if wGrab in flags:
    hover.flags.excl(wGrab)
    hover.vtable.handle(hover, outGrab)
  # Remove Hover
  if wHover in flags:
    hover.flags.excl(wHover)
    hover.vtable.handle(hover, outHover)

proc floor(man: GUIManager, idx: int) =
  let
    d = man.depth
    l = man.stack.len
    r = max(l - idx, 0)
    i0 = min(l, idx)
  # Handle Hover Out
  var i = i0 - 1
  while i >= 0:
    man.unhover(i)
    # Next Hover
    dec(i)
  # Floor Hover Elements
  copyMem(
    addr man.stack[0],
    addr man.stack[i0],
    GUIForward.sizeof * r)
  # Floor Hover Stack
  setLen(man.stack, r)
  man.depth = max(d - i0, 0)

proc land(man: GUIManager) =
  let depth = man.depth
  var i = high(man.stack)
  # Handle Hover Out
  while i >= depth:
    man.unhover(i)
    # Next Hover
    dec(i)
  # Land Hover Stack
  setLen(man.stack, depth)

proc unhover*(man: GUIManager) =
  var i = high(man.stack)
  # Handle Hover Out
  while i >= 0:
    man.unhover(i)
    # Next Hover
    dec(i)
  # Clear Hover Stack
  setLen(man.stack, 0)
  man.depth = 0

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
  # Find Current Hold
  if not isNil(man.hold):
    result = man.hold
  # Find Last Popup
  elif not isNil(man.popup.last):
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
  # Change Widget Hover
  if widget.pointOnArea(state.mx, state.my):
    flags.incl(wHover)
  else: flags.excl(wHover)
  # Change Widget Grab
  if state.kind == evCursorClick:
    flags.incl(wGrab)
  elif state.kind == evCursorRelease:
    flags.excl(wGrab)
  # Check Flags Changes
  let
    handle = widget.vtable.handle
    check = flags.delta(widget.flags)
  # React to Hover Changes
  if wHover in check:
    if wHover in flags: handle(widget, inHover)
    else: handle(widget, outHover)
  # React to Grab Changes
  if wGrab in check:
    if wGrab in flags: handle(widget, inGrab)
    else: handle(widget, outGrab)
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
    # Find Next Innermost Widget
    next = next.find(widget, state.mx, state.my)
    # Forward Event
    if next != widget:
      jump[] = next.parent
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
    next = state.kind == evFocusNext
    back = state.kind == evFocusPrev
  var focus {.cursor.} = man.focus
  # Fallback to Hold Widget
  if isNil(focus):
    focus = man.hold
  # Step Focus Cycle
  elif next or back:
    man.step(back)
    return true
  # Dispatch Keyboard Event
  result = not isNil(focus) and wKeyboard in focus.flags
  if result: focus.vtable.event(focus, state)

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
      w = w.inside(state.mx, state.my)
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

# -------------------
# Widget Hold Manager
# -------------------

proc hold*(man: GUIManager, widget: GUIWidget) =
  if not isNil(man.hold): return
  # Remove Focus
  man.unfocus()
  # Floor Stack to Hold
  let l = len(man.stack)
  for i in 0 ..< l:
    if man.stack[i].hover == widget:
      man.backup = man.stack
      setLen(man.backup, i)
      # Floor Stack
      man.floor(i)
      break
  # Handle Hold Change
  widget.flags.incl(wHold)
  widget.vtable.handle(widget, inHold)
  # Define Window Hold
  man.hold = widget

proc unhold*(man: GUIManager) =
  if isNil(man.hold): return
  let
    hold = man.hold
    shift = len(man.backup)
  # Remove Focus
  man.unfocus()
  # Restore Hover Stack
  if shift > 0:
    let l = len(man.stack)
    setLen(man.stack, l + shift)
    # Copy Backup Shift to Stack
    const bytes = sizeof(GUIForward)
    moveMem(addr man.stack[shift], addr man.stack[0], bytes * l)
    copyMem(addr man.stack[0], addr man.backup[0], bytes * shift)
    # Remove Backup Stack
    wasMoved(man.backup)
  # Remove Hover Otherwise
  else: man.unhover()
  # Handle Hold Change
  hold.flags.excl(wHold)
  hold.vtable.handle(hold, outHold)
  # Remove Window Hold
  man.hold = nil

# -----------------------
# Widget Toplevel Manager
# -----------------------

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
  # Remove Focus if was Inside
  let focus {.cursor.} = man.focus
  if not isNil(focus) and not focus.focusable():
    man.unfocus()
  # Handle Widget Detach
  widget.flags.excl(wVisible)
  widget.vtable.handle(widget, outFrame)
  # Floor Stack to Next Toplevel if not Holded
  if not isNil(man.hold): return
  let l = len(man.stack)
  for i in 0 ..< l:
    if man.stack[i].hover.kind >= wkRoot:
      man.floor(i)
      break

# ---------------------
# Widget Layout Manager
# ---------------------

proc layout*(man: GUIManager, widget: GUIWidget) =
  if wVisible in widget.flags:
    widget.arrange()
    # Check if Focus is Lost
    let focus {.cursor.} = man.focus
    if not isNil(focus) and not focus.focusable():
      man.unfocus()

# ------------------------
# Widget Manager Configure
# ------------------------

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
  # Reserve Forward Stack Capacity
  result.stack = newSeqOfCap[GUIForward](8)
