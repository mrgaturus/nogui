from signal import
  GUISignal, GUITarget,
  WidgetSignal, send, delay
from render import 
  CTXRender, GUIRect, push, pop
# Native Platform State
from ../native/native import GUIState

type
  GUIFlag* = enum
    wVisible
    wHidden
    # Enabled Status
    wMouse
    wKeyboard
    # Event Status
    wFocus
    wHover
    wGrab
  GUIFlags* = set[GUIFlag]

const
  wStandard* = {wMouse, wKeyboard}
  # Event Status Checking
  wFocusable* = {wVisible, wKeyboard}
  wHoverGrab* = {wHover, wGrab}

type
  GUIHandle* = enum
    inFocus, inHover, inFrame
    outFocus, outHover, outFrame
  GUIKind* = enum
    wgRoot, wgChild, wgFrame # Basic
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

# -------------------
# WIDGET TREE WALKERS
# -------------------

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

proc contains*(flags, mask: GUIFlags): bool {.inline.} =
  mask * flags == mask

proc some*(flags, mask: GUIFlags): bool {.inline.} =
  mask * flags != {}

# -- Widget Flags Testing
proc test*(self: GUIWidget, flag: GUIFlag): bool {.inline.} =
  contains(self.flags, flag)

proc test*(self: GUIWidget, mask: GUIFlags): bool {.inline.} =
  mask * self.flags == mask

proc some*(self: GUIWidget, mask: GUIFlags): bool {.inline.} =
  mask * self.flags != {}

# -- Widget Weak Cursor
proc target*(self: GUIWidget): GUITarget {.inline.} =
  cast[GUITarget](self) # Avoid Ref Count Loosing

# ---------------------
# WIDGET CHILDREN PROCS
# ---------------------

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

# ----------------------------------------------
# WIDGET SLIBINGS PROCS
# TODO: CHECK IF ATTACHED TO AVOID DOUBLE ATTACH
# ----------------------------------------------

proc replace*(self, widget: GUIWidget) =
  var w {.cursor.}: GUIWidget
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
  if not isNil(w):
    if w.first == self:
      w.first = widget
    if w.last == self:
      w.last = widget

proc attachNext*(self, widget: GUIWidget) =
  var w {.cursor.}: GUIWidget
  # Replace Next Previous
  w = self.next
  if not isNil(w):
    w.prev = widget
  # Replace Sides
  widget.next = w
  widget.prev = self
  # Replace Next
  self.next = widget
  # Replace Parent
  w = self.parent
  if not isNil(w) and w.last == self:
    w.last = widget
  widget.parent = w

proc attachPrev*(self, widget: GUIWidget) =
  var w {.cursor.}: GUIWidget
  # Replace Previous Next
  w = self.prev
  if not isNil(w):
    w.next = widget
  # Replace Sides
  widget.next = self
  widget.prev = w
  # Replace Prev
  self.prev = widget
  # Replace Parent
  w = self.parent
  if not isNil(w) and w.first == self:
    w.first = widget
  widget.parent = w

proc detach*(self: GUIWidget) =
  # Replace Prev
  if not isNil(self.prev):
    self.prev.next = self.next
  # Replace Next
  if not isNil(self.next):
    self.next.prev = self.prev
  # Replace Parent Endpoints
  let w {.cursor.} = self.parent
  if not isNil(w):
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
  wVisible in widget.flags and
    x >= rect.x and x <= rect.x + rect.w and
    y >= rect.y and y <= rect.y + rect.h

# -----------------------------
# WIDGET FRAMED Move and Resize
# -----------------------------

proc open*(widget: GUIWidget) {.inline.} =
  send(widget.target, wsOpen)

proc close*(widget: GUIWidget) {.inline.} =
  send(widget.target, wsClose)

proc move*(widget: GUIWidget, x, y: int32) =
  if widget.kind > wgChild:
    widget.metrics.x = int16 x
    widget.metrics.y = int16 y
    # Send Layout Signal
    delay(widget.target, wsLayout)

proc resize*(widget: GUIWidget, w, h: int32) =
  if widget.kind > wgChild:
    let metrics = addr widget.metrics
    metrics.w = max(int16 w, metrics.minW)
    metrics.h = max(int16 h, metrics.minH)
    # Send Layout Signal
    delay(widget.target, wsLayout)

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
  # Find Children
  while true:
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
  var w {.cursor.} = widget
  # Point Inside All Parents?
  while w.parent != nil:
    if not w.pointOnArea(x, y):
      result = w.parent
    w = w.parent
  # Find Inside of Outside
  if not isNil(result.last):
    result = inside(result, x, y)

# -------------------------------
# WIDGET STEP FOCUS - EVENT QUEUE
# -------------------------------

proc visible*(widget: GUIWidget): bool =
  var cursor = widget
  # Test Self Visibility
  result = wVisible in cursor.flags
  # Walk to Outermost Parent
  while result:
    cursor = cursor.parent
    if isNil(cursor): break
    else: # Test Parent Visibility
      result = wVisible in cursor.flags

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
    if result.flags * wFocusable == wFocusable or 
      result == widget: break

# --------------------------------
# WIDGET LAYOUT TREE - EVENT QUEUE
# TODO: use names freed by removing vtable templates alias
# --------------------------------

proc absolute(widget: GUIWidget) =
  let
    rect = addr widget.rect
    metrics = addr widget.metrics
  var flags = widget.flags
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
  let test = (wHidden notin flags) and
    rect.x <= pivot.x + pivot.w and
    rect.y <= pivot.y + pivot.h and
    rect.x + rect.w >= pivot.x and
    rect.y + rect.h >= pivot.y
  # Mark Visible if Passed Visibility Test
  flags.excl(wVisible)
  if test: flags.incl(wVisible)
  # Replace Flags
  widget.flags = flags

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
    if wVisible in w.flags:
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
    # Push Clipping
    if wVisible in w.flags:
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
