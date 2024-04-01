from event import GUIState
from signal import
  GUISignal, GUITarget,
  WidgetSignal, pushSignal
from render import 
  CTXRender, GUIRect, push, pop

const # Widget Bit-Flags
  wDirty* = uint8(1 shl 0) # C
  # Hidden and Visibility Check
  wHidden* = uint8(1 shl 1) # C
  wVisible* = uint8(1 shl 2) # A
  # Separated Enabled Status
  wKeyboard* = uint8(1 shl 3) # C
  wMouse* = uint8(1 shl 4) # C
  # Focus, Hover and Grab
  wFocus* = uint8(1 shl 5) # C
  wHover* = uint8(1 shl 6) # A
  wGrab* = uint8(1 shl 7) # A
  # -- Initializing Masks
  wMouseKeyboard* = wMouse or wKeyboard
  # -- Status Checking Masks
  wHoverGrab* = wHover or wGrab
  wFocusCheck* = wVisible or wKeyboard
  # -- Set/Clear Handle Masks
  wHandleMask = wFocus or wDirty
  wHandleClear = wFocus or wFocusCheck
  wProtected = # Protect Automatics
    not(wVisible or wHover or wGrab)

type
  GUIFlags* = uint8
  GUIHandle* = enum
    inFocus, inHover, inFrame
    outFocus, outHover, outFrame
  GUIKind* = enum
    wgChild, wgFrame # Basic
    wgPopup, wgMenu, wgTooltip
  # Widget VTable Methods
  GUIMethods* {.pure.} = object
    handle*: proc(self: GUIWidget, kind: GUIHandle) {.noconv.}
    event*: proc(self: GUIWidget, state: ptr GUIState) {.noconv.}
    update*: proc(self: GUIWidget) {.noconv.}
    layout*: proc(self: GUIWidget) {.noconv.}
    draw*: proc(self: GUIWidget, ctx: ptr CTXRender) {.noconv.}
  # Widget Metrics
  GUIMetrics* = object
    x*, y*, w*, h*: int16
    # Dimensions Hint
    minW*, minH*: int16
    maxW*, maxH*: int16
  GUIWidget* {.inheritable.} = ref object
    vtable*: ptr GUIMethods
    # Widget Node Tree
    parent*: GUIWidget
    next*, prev*: GUIWidget
    first*, last*: GUIWidget
    # Widget Flags
    kind*: GUIKind
    flags*: GUIFlags
    # Widget Rect&Hint
    rect*: GUIRect
    metrics*: GUIMetrics

# -----------------------------------------------
# WIDGET ABSTRACT METHODS - TODO: GET RID OF THIS
# -----------------------------------------------

template handle*(w: GUIWidget, kind: GUIHandle) = w.vtable.handle(w, kind)
template event*(w: GUIWidget, state: ptr GUIState) = w.vtable.event(w, state)
template update*(w: GUIWidget) = w.vtable.update(w)
template layout*(w: GUIWidget) = w.vtable.layout(w)
template draw*(w: GUIWidget, ctx: ptr CTXRender) = w.vtable.draw(w, ctx)

# ----------------------------
# WIDGET NEIGHTBORDS ITERATORS
# ----------------------------

# First -> Last
iterator forward*(first: GUIWidget): GUIWidget =
  var frame = first
  while not isNil(frame):
    yield frame
    frame = frame.next

# Last -> First
iterator reverse*(last: GUIWidget): GUIWidget =
  var frame = last
  while not isNil(frame):
    yield frame
    frame = frame.prev

# ------------------------------------
# WIDGET SIGNAL & FLAGS HANDLING PROCS
# ------------------------------------

# -- Widget Signal Target
proc target*(self: GUIWidget): GUITarget {.inline.} =
  cast[GUITarget](self) # Avoid Ref Count Loosing

# -- Unsafe Flags Handling
proc set*(flags: var GUIFlags, mask: GUIFlags) {.inline.} =
  flags = flags or mask

proc clear*(flags: var GUIFlags, mask: GUIFlags) {.inline.} =
  flags = flags and not mask

# -- Safe Flags Handling
proc set*(self: GUIWidget, mask: GUIFlags) =
  var delta = mask and not self.flags
  # Check if mask needs handling
  if (delta and wHandleMask) > 0:
    let target = self.target
    # Relayout Widget and Childrens
    if (delta and wDirty) == wDirty:
      pushSignal(target, msgDirty)
    # Request Replace Window Focus
    if (delta and wFocus) == wFocus:
      pushSignal(target, msgFocus)
  self.flags = # Merge Flags Mask
    self.flags or (delta and wProtected)

proc clear*(self: GUIWidget, mask: GUIFlags) =
  let delta = mask and self.flags
  # Check if mask needs handling
  if (delta and wHandleClear) > 0:
    pushSignal(self.target, msgCheck)
  self.flags = # Clear Flags Mask
    self.flags and not (delta and wProtected)

# -- Flags Testing
proc any*(self: GUIWidget, mask: GUIFlags): bool {.inline.} =
  return (self.flags and mask) > 0

proc test*(self: GUIWidget, mask: GUIFlags): bool {.inline.} =
  return (self.flags and mask) == mask

# ----------------------------
# WIDGET ADD CHILD NODES PROCS
# ----------------------------

proc add*(self, widget: GUIWidget) =
  widget.parent = self
  # Add Widget to List
  if self.first.isNil:
    self.first = widget
  else: # Add to Last
    widget.prev = self.last
    self.last.next = widget
  # Set Widget To Last
  self.last = widget
  # Set Kind as Children
  widget.kind = wgChild

proc replace*(self, widget: GUIWidget) =
  var w {.cursor.}: GUIWidget
  # Debug Check
  assert self.kind == widget.kind
  assert widget.kind == wgChild
  # Replace Prev
  if not isNil(self.prev):
    w = self.prev
    w.next = widget
    widget.prev = w
  # Replace Next
  if not isNil(self.next):
    w = self.next
    w.prev = widget
    widget.next = w
  # Replace Parent
  w = self.parent
  widget.parent = w
  if not isNil(self.parent):
    if w.first == self:
      w.first = widget
    if w.last == self:
      w.last = widget

proc detach*(self: GUIWidget) =
  assert self.kind == wgChild
  # Replace Prev
  if not isNil(self.prev):
    self.prev.next = self.next
  # Replace Next
  if not isNil(self.next):
    self.next.prev = self.prev
  # Replace Parent Extremuns
  let w {.cursor.} = self.parent
  if not isNil(self.parent):
    if w.first == self:
      w.first = self.next
    if w.last == self:
      w.last = self.prev

# --------------------------------------
# WIDGET RECT PROCS layout & Mouse event
# --------------------------------------

proc geometry*(widget: GUIWidget, x, y, w, h: int32) =
  let metrics = addr widget.metrics
  # Change Geometry Size
  metrics.x = cast[int16](x)
  metrics.y = cast[int16](y)
  metrics.w = cast[int16](w)
  metrics.h = cast[int16](h)

proc geometry*(widget: GUIWidget, rect: GUIRect) {.inline.} =
  # Unpack Rect and Use Previous Proc
  widget.geometry(rect.x, rect.y, rect.w, rect.h)

proc minimum*(widget: GUIWidget, w, h: int32) =
  let metrics = addr widget.metrics
  # Change Geometry Size
  metrics.minW = cast[int16](w)
  metrics.minH = cast[int16](h)

proc maximum*(widget: GUIWidget, w, h: int32) =
  let metrics = addr widget.metrics
  # Change Geometry Size
  metrics.maxW = cast[int16](w)
  metrics.maxH = cast[int16](h)

proc pointOnArea*(widget: GUIWidget, x, y: int32): bool =
  let rect = addr widget.rect
  # Check if is visible and point is on area
  (widget.flags and wVisible) == wVisible and
    x >= rect.x and x <= rect.x + rect.w and
    y >= rect.y and y <= rect.y + rect.h

# -----------------------------
# WIDGET FRAMED Move and Resize
# -----------------------------

proc open*(widget: GUIWidget) =
  let target = widget.target
  case widget.kind
  of wgFrame: # Subwindow
    pushSignal(target, msgFrame)
  of wgPopup, wgMenu: # Stacked
    pushSignal(target, msgPopup)
  of wgTooltip: # Tooltip
    pushSignal(target, msgTooltip)
  of wgChild: discard # Invalid

proc close*(widget: GUIWidget) {.inline.} =
  pushSignal(widget.target, msgClose)

proc move*(widget: GUIWidget, x, y: int32) =
  if widget.kind > wgChild:
    widget.metrics.x = int16 x
    widget.metrics.y = int16 y
    # Mark Widget as Dirty
    widget.set(wDirty)

proc resize*(widget: GUIWidget, w, h: int32) =
  if widget.kind > wgChild:
    let metrics = addr widget.metrics
    metrics.w = max(int16 w, metrics.minW)
    metrics.h = max(int16 h, metrics.minH)
    # Mark Widget as Dirty
    widget.set(wDirty)

# ----------------------------
# WIDGET FINDING - EVENT QUEUE
# ----------------------------

proc outside*(widget: GUIWidget): GUIWidget =
  result = widget
  # Walk to Outermost Parent
  while not isNil(result.parent):
    result = result.parent

proc inside(widget: GUIWidget, x, y: int32): GUIWidget =
  result = widget.last
  while true: # Find Children
    if pointOnArea(result, x, y):
      if isNil(result.last):
        return result
      else: # Find Inside
        result = result.last
    # Check Prev Widget
    if isNil(result.prev):
      return result.parent
    else: # Prev Widget
      result = result.prev

proc find*(widget: GUIWidget, x, y: int32): GUIWidget =
  # Initial Widget
  result = widget
  # Initial Cursor
  var cursor = widget
  # Point Inside All Parents?
  while cursor.parent != nil:
    if not pointOnArea(cursor, x, y):
      result = cursor.parent
    cursor = cursor.parent
  # Find Inside of Outside
  if not isNil(result.last):
    result = inside(result, x, y)

# -------------------------------
# WIDGET STEP FOCUS - EVENT QUEUE
# -------------------------------

proc visible*(widget: GUIWidget): bool =
  var cursor = widget
  # Test Self Visibility
  result = cursor.test(wVisible)
  # Walk to Outermost Parent
  while result:
    cursor = cursor.parent
    if isNil(cursor): break
    else: # Test Parent Visibility
      result = cursor.test(wVisible)

proc step*(widget: GUIWidget, back: bool): GUIWidget =
  result = widget
  # Step Neightbords
  while true:
    result = # Step Widget
      if back: result.prev
      else: result.next
    # Reroll Widget
    if isNil(result):
      result = # Restart Widget
        if back: widget.parent.last
        else: widget.parent.first
    # Check if is Focusable or is the same again
    if result.test(wFocusCheck) or 
      result == widget: break

# --------------------------------
# WIDGET LAYOUT TREE - EVENT QUEUE
# TODO: use names freed by removing vtable templates alias
# --------------------------------

proc absolute(widget: GUIWidget) =
  let
    rect = addr widget.rect
    metrics = addr widget.metrics
    flags = widget.flags
  # Calcule Absolute Position
  rect.x = metrics.x
  rect.y = metrics.y
  # Calculate Absolute Size
  rect.w = metrics.w
  rect.h = metrics.h
  # Absolute is Relative when no parent
  if isNil(widget.parent): return
  # Move Absolute Position to Pivot
  let pivot = addr widget.parent.rect
  rect.x += pivot.x
  rect.y += pivot.y
  # Test Visibility Boundaries
  let test = (flags and wHidden) == 0 and
    rect.x <= pivot.x + pivot.w and
    rect.y <= pivot.y + pivot.h and
    rect.x + rect.w >= pivot.x and
    rect.y + rect.h >= pivot.y
  # Mark Visible if Passed Visibility Test
  widget.flags = (flags and not wVisible) or 
    (cast[uint8](test) shl 2) # See wVisible

proc prepare(widget: GUIWidget) =
  var w {.cursor.} = widget
  # Traverse Children
  while true:
    # Traverse Inside?
    if isNil(w.first):
      w.vtable.update(w)
    else:
      w = w.first
      continue
    # Traverse Parents?
    while isNil(w.next) and w != widget:
      w = w.parent
      w.vtable.update(w)
    # Traverse Slibings?
    if w == widget: break
    else: w = w.next
    
proc organize(widget: GUIWidget) =
  var w {.cursor.} = widget
  # Traverse Children
  while true:
    w.absolute()
    # Is Visible?
    if w.test(wVisible):
      w.vtable.layout(w)
      # Traverse Inside?
      if not isNil(w.first):
        w = w.first
        continue
    # Traverse Parents?
    while isNil(w.next) and w != widget:
      w = w.parent
    # Traverse Slibings?
    if w == widget: break
    else: w = w.next

proc arrange*(widget: GUIWidget) =
  var
    w {.cursor.} = widget
    m = w.metrics
  # Prepare Widget
  w.prepare()
  # Propagate Metrics Changes to Parents
  while w.metrics != m and not isNil(w.parent):
    w = w.parent
    m = w.metrics
    # Prepare Widget
    w.vtable.update(w)
  # Layout Widgets
  w.organize()

# -----------------------------------
# WIDGET RENDER CHILDRENS - MAIN LOOP
# Create a flag for check if needs clipping
# -----------------------------------

proc render*(widget: GUIWidget, ctx: ptr CTXRender) =
  var w {.cursor.} = widget
  # Push Clipping
  ctx.push(w.rect)
  # Traverse Children
  while true:
    # Push Clipping, TODO: Change to Nim sets
    if (w.flags and wVisible) == wVisible:
      w.vtable.draw(w, ctx)
      # Traverse Inside?
      if not isNil(w.first):
        ctx.push(w.rect)
        w = w.first
        continue
    # Traverse Parents?
    while isNil(w.next) and w != widget:
      ctx.pop()
      w = w.parent
    # Traverse Slibings?
    if w == widget: break
    else: w = w.next
  # Pop Clipping
  ctx.pop()
