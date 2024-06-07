from render import CTXRender
from metrics import GUIMetrics, GUIRect
from ../native/ffi import GUIState
# Export Widget Metrics
export GUIMetrics, GUIRect

type
  GUIFlag* = enum
    wVisible
    wHidden
    # Enabled Status
    wMouse
    wKeyboard
    # Event Status
    wHover, wGrab
    wFocus, wHold
  GUIFlags* = set[GUIFlag]

type
  GUIHandle* = enum
    inHover, outHover
    inGrab, outGrab
    inFocus, outFocus
    # Window Toplevel
    inHold, outHold
    inFrame, outFrame
  GUIKind* = enum
    wkWidget
    wkForward
    wkLayout
    wkContainer
    # Toplevel
    wkRoot
    wkFrame
    wkPopup
    wkTooltip
  # Widget VTable Methods
  GUIMethods* {.pure.} = object
    handle*: proc(self: GUIWidget, reason: GUIHandle) {.noconv.}
    event*: proc(self: GUIWidget, state: ptr GUIState) {.noconv.}
    update*: proc(self: GUIWidget) {.noconv.}
    layout*: proc(self: GUIWidget) {.noconv.}
    draw*: proc(self: GUIWidget, ctx: ptr CTXRender) {.noconv.}
  # Widget Object
  GUITarget* = distinct pointer
  GUIWidget* {.inheritable.} = ref object
    vtable*: ptr GUIMethods
    parent* {.cursor.}: GUIWidget
    # Widget Node Tree
    next*, first*: GUIWidget
    prev* {.cursor.}: GUIWidget
    last* {.cursor.}: GUIWidget
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
  var frame {.cursor.} = first
  while not isNil(frame):
    yield frame
    frame = frame.next

# Last -> First
iterator reverse*(last: GUIWidget): GUIWidget =
  var frame {.cursor.} = last
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

proc delta*(flags, mask: GUIFlags): GUIFlags {.inline.} =
  {.emit: "`result` = `flags` ^ `mask`;".}

# -- Widget Flags Testing
proc test*(self: GUIWidget, flag: GUIFlag): bool {.inline.} =
  contains(self.flags, flag)

proc test*(self: GUIWidget, mask: GUIFlags): bool {.inline.} =
  mask * self.flags == mask

proc some*(self: GUIWidget, mask: GUIFlags): bool {.inline.} =
  mask * self.flags != {}

# -- Widget Weak Cursor
converter target*(self: GUIWidget): GUITarget {.inline.} =
  cast[GUITarget](self) # Avoid ORC Cycle

converter unwrap*(self: GUITarget): GUIWidget {.inline.} =
  cast[GUIWidget](self) # Avoid ORC Cycle

# ---------------------
# WIDGET CHILDREN PROCS
# ---------------------

proc add*(self, widget: GUIWidget) =
  widget.parent = self
  widget.next = nil
  # Add Widget to List
  if isNil(self.first):
    widget.prev = nil
    self.first = widget
  else: # Add to Last
    widget.prev = self.last
    self.last.next = widget
  # Set Widget To Last
  self.last = widget

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
  var w {.cursor.} = self.next
  widget.next = w
  widget.prev = self
  # Replace Next
  if not isNil(w):
    w.prev = widget
  self.next = widget
  # Replace Parent
  w = self.parent
  if not isNil(w) and w.last == self:
    w.last = widget
  widget.parent = w

proc attachPrev*(self, widget: GUIWidget) =
  var w {.cursor.} = self.prev
  widget.next = self
  widget.prev = w
  # Replace Previous
  if not isNil(w):
    w.next = widget
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
  # Check if is Visible and Point is on Area
  wVisible in widget.flags and
    x >= rect.x and x <= rect.x + rect.w and
    y >= rect.y and y <= rect.y + rect.h

# -------------------
# Widget Status Check
# -------------------

proc visible*(widget: GUIWidget): bool =
  var w {.cursor.} = widget
  result = wVisible in w.flags
  # Check Outermost Parent
  while result:
    w = w.parent
    if isNil(w): break
    # Check if Parent is Visible
    result = wVisible in w.flags

proc focusable*(widget: GUIWidget): bool =
  if widget.kind > wkWidget:
    return false
  # Check if Widget is Focusable
  var w {.cursor.} = widget
  result = {wVisible, wKeyboard} in w.flags
  # Check Outermost Parent
  while result:
    w = w.parent
    if isNil(w): break
    # Check if Parent is Visible and is a Layout
    result = wVisible in w.flags and w.kind > wkWidget
