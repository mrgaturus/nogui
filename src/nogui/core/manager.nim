import ../native/ffi
import widget, tree, callback

type
  GUILayer* = object
    first*: GUIWidget
    last* {.cursor.}: GUIWidget
  GUIForward = object
    hover: GUIWidget
    skip {.cursor.}: GUIWidget
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
    focus: GUIWidget
    hold: GUIWidget
    # Window Hover State
    stack: seq[GUIForward]
    depth, offset, stops: int
    grab, locked: bool

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
  man.offset = 0

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
  else: return
  # Define Current Stack Hover
  let fw = addr man.stack[i]
  fw.hover = widget
  fw.jump = widget
  fw.skip = widget

# ----------------------
# Cursor Forward Manager
# ----------------------

proc cursorOuter(man: GUIManager, x, y: int32): GUIWidget =
  if not isNil(man.hold):
    man.depth = man.offset
    return man.hold
  elif man.locked:
    return man.stack[0].hover
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

proc cursorGrab(man: GUIManager, widget: GUIWidget) =
  let state = man.state
  var flags = widget.flags
  # Change Widget Hover
  if widget.pointOnArea(state.mx, state.my):
    flags.incl(wHover)
  else: flags.excl(wHover)
  # Change Widget Grab
  if man.grab: flags.incl(wGrab)
  else: flags.excl(wGrab)
  # Check Flags Changes
  let
    handle = widget.vtable.handle
    check = flags.delta(widget.flags)
  # Replace Widget Flags
  widget.flags = flags
  # React to Hover Changes
  if wHover in check:
    if wHover in flags: handle(widget, inHover)
    else: handle(widget, outHover)
  # React to Grab Changes
  if wGrab in check:
    if wGrab in flags: handle(widget, inGrab)
    else: handle(widget, outGrab)

proc cursorSkip(man: GUIManager): bool =
  let
    state = man.state
    locked = man.locked
    # Current Forward
    depth = man.depth - 1
    fw = addr man.stack[depth]
  # Find Skip Innermost Widget
  var w {.cursor.} = fw.jump
  let skip {.cursor.} = fw.skip
  if skip.kind in {wkLayout, wkContainer} and not locked:
    w = w.find(skip, state.mx, state.my)
  # Skip Forward if has Grab of Hover
  let inside = w != skip or w.pointOnArea(state.mx, state.my)
  if locked or inside:
    send(man.cbForward, w)
    fw.jump = w
    # Forward Skiped
    return true
  # Remove Cursor Skip
  fw.skip = fw.hover
  fw.jump = fw.hover

proc cursorStep(man: GUIManager, widget: GUIWidget) =
  let
    state = man.state
    depth = man.depth
  # Dispatch Cursor Event
  if wMouse in widget.flags:
    widget.vtable.event(widget, state)
  # Forward to Stack Next if Locked
  if man.locked and depth < len(man.stack):
    let next {.cursor.} = man.stack[depth].hover
    send(man.cbForward, next)
  # Forward to Next Inside Widget
  elif widget.kind >= wkRoot or widget.kind == wkForward:
    let fw = addr man.stack[depth - 1]
    # Find Next Inside Widget
    var next {.cursor.} = fw.jump
    next = next.find(widget, state.mx, state.my)
    if next != widget:
      fw.jump = next
      send(man.cbForward, next)

proc cursorForward(man: GUIManager, widget: GUIWidget) =
  var fw: ptr GUIForward
  let depth = man.depth
  # Avoid Redundant Widget Forward
  var idx = man.depth - 1
  while idx >= 0:
    fw = addr man.stack[idx]
    if fw.hover == widget:
      return
    dec(idx)
  # Prepare Cursor Step
  man.hover(widget)
  man.cursorGrab(widget)
  # Step Forward if was not Skipped
  fw = addr man.stack[depth]
  if fw.skip == widget or not man.cursorSkip():
    man.cursorStep(widget)

# ----------------------
# Event Dispatch Manager
# ----------------------

proc cursorEvent*(man: GUIManager, state: ptr GUIState) =
  man.state = state
  man.depth = 0
  man.stops = 0
  # Avoid Grab to Nothing
  if man.locked and len(man.stack) == 0:
    return
  # Check Cursor Grab Status
  let outer = man.cursorOuter(state.mx, state.my)
  if state.kind == evCursorClick:
    man.grab = true
    # Elevate Outer Frame when Clicked
    if outer.kind == wkFrame:
      elevate(man.frame, outer)
  elif state.kind == evCursorRelease:
    man.grab = false
  # Dispatch Cursor Event
  man.cursorForward(outer)
  send(man.cbLand)

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
    # Forward Widget
    man.cursorForward(w)
  # Forward Key Event
  of evKeyDown, evKeyUp:
    if wKeyboard in widget.flags:
      widget.vtable.event(widget, state)
  # Skip Invalid Event
  else: discard

proc redirect*(man: GUIManager, widget: GUIWidget) =
  let
    state = man.state
    hover = widget.pointOnArea(state.mx, state.my)
  # Mark Current Forward as Redirect
  if man.locked or hover:
    let depth = man.depth - 1
    if depth >= 0:
      man.stack[depth].skip = widget
      man.stack[depth].jump = widget
    # Step Forward Widget
    man.forward(widget)

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
  # Check Offset at Stack
  let depth = man.depth - 1
  var idx = depth
  while idx >= 0:
    if widget == man.stack[idx].hover:
      break
    # Next Offset
    dec(idx)
  if idx < 0:
    man.hover(widget)
    idx = depth
  # Handle Hold Change
  widget.flags.incl(wHold)
  widget.vtable.handle(widget, inHold)
  # Define Window Hold
  man.hold = widget
  man.offset = idx

proc unhold*(man: GUIManager) =
  if isNil(man.hold): return
  let hold {.cursor.} = man.hold
  # Remove Focus
  man.unfocus()
  # Handle Hold Change
  hold.flags.excl(wHold)
  hold.vtable.handle(hold, outHold)
  # Remove Window Hold
  man.hold = nil
  man.offset = 0

proc ungrab*(man: GUIManager) =
  var i = high(man.stack)
  while i >= 0:
    # Ungrab Widgets From Stack
    let w {.cursor.} = man.stack[i].hover
    if wGrab in w.flags:
      w.flags.excl(wGrab)
      w.vtable.handle(w, outGrab)
    # Next Forward
    dec(i)
  # Stop Manager Grabbed
  man.grab = false
  man.locked = false

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
  if wVisible notin widget.flags: return
  # Detach Widget from Layer
  let la = man.layer(widget)
  if isNil(la): return
  la[].detach(widget)
  # Remove Widget Visible
  widget.flags.excl(wVisible)
  # Remove Focus if was Inside
  let focus {.cursor.} = man.focus
  if not isNil(focus) and not focus.focusable():
    man.unfocus()
  # Handle Widget Detach
  widget.vtable.handle(widget, outFrame)

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
  man.locked = man.grab
  # Remove Current Hovered
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
