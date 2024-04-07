type
  # Callback Generic Data
  GUITarget* = distinct pointer
  GUIOpaque* = object
  # Callback Generic Proc
  GUICallbackProc =
    proc(sender: pointer) {.nimcall.}
  GUICallbackProcEX = # With Parameter
    proc(sender, extra: pointer) {.nimcall.}
  # Signal Callback
  GUICallback* = object
    sender, fn: pointer
  GUICallbackEX*[T] = 
    distinct GUICallback

type
  # Signal Mode
  SignalKind* = enum
    sCallback
    sCallbackEX
    # Special Kinds
    sWidget, sWindow
  # Signal Special
  WidgetSignal* = enum
    wsLayout
    wsFocus
    # Toplevel
    wsOpen
    wsClose
  WindowSignal* = enum
    wsTerminate
    wsFocusOut
    wsHoverOut
    # Input Method
    wsOpenIM
    wsCloseIM
  # Signal Object
  Signal = object
    next: GUISignal
    bytes: int
    # Signal Mode
    case kind*: SignalKind
    of sCallback, sCallbackEX:
      cb*: GUICallback
    of sWidget:
      target*: GUITarget
      ws*: WidgetSignal
    of sWindow:
      msg*: WindowSignal
    # Signal Data
    data*: GUIOpaque
  GUISignal* = ptr Signal

# ---------------------
# Signal Queue Creation
# ---------------------

type
  # GUI Signal and Queue
  Queue = object
    first, last: GUISignal
    undo, once: GUISignal
  GUIQueue* = ptr Queue
# Global GUI Queue
var opaque: GUIQueue

proc newGUIQueue*(): GUIQueue =
  result = create(Queue)
  # GUI Queue Global
  opaque = result

proc newSignal(size = 0): GUISignal =
  let bytes = Signal.sizeof + size
  result = cast[GUISignal](alloc0 bytes)
  # Define Fundamental Header
  result.next = nil
  result.bytes = bytes

proc expose*(queue: GUIQueue): tuple[queue, cherry: ptr pointer] =
  result.queue = cast[ptr pointer](addr queue.first)
  result.cherry = cast[ptr pointer](addr queue.once)

# -------------------------
# Signal Queue Manipulation
# -------------------------

proc push(queue: GUIQueue, signal: GUISignal) =
  if isNil(queue.first):
    queue.first = signal
    queue.last = signal
    return
  # Insert to Signal Queue
  let last = queue.last
  signal.next = last.next
  last.next = signal
  # Replace Last Signal
  queue.last = signal
  queue.undo = last

iterator poll*(queue: GUIQueue): GUISignal =
  var signal = queue.first
  # Poll Signals
  while signal != nil:
    queue.last = signal
    yield signal
    # Use First as Previous
    queue.first = signal
    signal = signal.next
    # Dealloc Previous
    dealloc(queue.first)
  # Clear Queue
  queue.first = nil
  queue.last = nil

# ---------------------
# Signal Queue Postpone
# ---------------------

proc delay(queue: GUIQueue, signal: GUISignal) =
  var
    once = queue.once
    last = once
  # Add when has Nothing
  if isNil(once):
    queue.once = signal
    return
  # Check if is already postponed
  let bytes = signal.bytes
  while once != nil:
    # Compare if is actually the same
    if equalMem(signal, once, bytes):
      dealloc(signal)
      return
    # Next Pending Signal
    last = once
    once = once.next
  # Add To Last
  last.next = signal

proc cherry(queue: GUIQueue) =
  let
    undo = queue.undo
    last = queue.last
  # Consume Cherry Peek
  queue.last = undo
  if not isNil(undo):
    undo.next = last.next
    queue.undo = nil
  # Delay Callback
  last.next = nil
  queue.delay(last)

proc pending*(queue: GUIQueue) =
  assert isNil(queue.first)
  # Consume Delayed Queues
  queue.first = queue.once
  queue.once = nil

# --------------------
# Signal Queue Destroy
# --------------------

proc destroy(first: GUISignal) =
  var
    signal = first
    prev = first
  while signal != nil:
    # Use First as Previous
    prev = signal
    signal = signal.next
    # Dealloc Previous
    dealloc(prev)

proc destroy*(queue: GUIQueue) =
  destroy(queue.first)
  destroy(queue.once)
  # Dealloc Queue
  dealloc(queue)

# ----------------------
# Signal Special Sending
# ----------------------

proc send*(target: GUITarget, ws: WidgetSignal) =
  assert(not cast[pointer](target).isNil)
  # Get Queue Pointer from Global
  let 
    queue = opaque
    signal = newSignal()
  # Widget Signal Kind
  signal.kind = sWidget
  signal.target = target
  signal.ws = ws
  # Add new signal to Front
  queue.push(signal)

proc send*(msg: WindowSignal) =
  # Get Queue Pointer from Global
  let
    queue = opaque
    signal = newSignal()
  # Application Signal Kind
  signal.kind = sWindow
  signal.msg = msg
  # Add new signal to Front
  queue.push(signal)

# --------------------
# Signal Special Delay
# --------------------

proc delay*(target: GUITarget, ws: WidgetSignal) =
  target.send(ws); opaque.cherry()

proc delay*(msg: WindowSignal) =
  msg.send(); opaque.cherry()

# -----------------------
# Signal Callback Sending
# -----------------------

proc send*(cb: GUICallback) =
  if isNil(cb.fn): return
  # Get Queue Pointer from Global
  let 
    queue = opaque
    signal = newSignal()
  # Assign Callback
  signal.kind = sCallback
  signal.cb = cb
  # Add new signal to Front
  queue.push(signal)

proc send(cb: GUICallback, data: pointer, size: Natural) =
  if isNil(cb.fn) or isNil(data): return
  # Get Queue Pointer from Global
  let
    queue = opaque
    signal = newSignal(size)
  # Assign Callback
  signal.kind = sCallbackEX
  signal.cb = cb
  # Copy Optionally Data
  if size > 0 and not isNil(data):
    copyMem(addr signal.data, data, size)
  # Add new signal to Front
  queue.push(signal)

template send*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).send(addr data, sizeof T)

# ---------------------
# Signal Callback Delay
# ---------------------

proc delay*(cb: GUICallback) =
  cb.send(); opaque.cherry()

proc delay(cb: GUICallback, data: pointer, size: Natural) =
  cb.send(data, size); opaque.cherry()

template delay*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).delay(addr data, sizeof T)

# -----------------------
# Signal Callback Forcing
# -----------------------

proc force*(cb: GUICallback) =
  let fn = cast[GUICallbackProc](cb.fn)
  # Execute if is Valid
  if not isNil(fn):
    fn(cb.sender)

proc forceEX(cb: GUICallback, data: pointer) =
  let fn = cast[GUICallbackProcEX](cb.fn)
  # Execute if is Valid
  if not (fn.isNil or data.isNil):
    fn(cb.sender, data)

template force*[T](cb: GUICallbackEX[T], data: ptr T) =
  forceEX(cb.GUICallback, data)

# -------------------------------
# Signal Callback Unsafe Creation
# -------------------------------

template unsafeCallback*(self: pointer, call: proc): GUICallback =
  GUICallback(sender: self, fn: cast[pointer](call))

template unsafeCallbackEX*[T](self: pointer, call: proc): GUICallbackEX[T] =
  GUICallbackEX[T](unsafeCallback(self, call))

# --------------------------
# Signal Callback Validation
# --------------------------

proc valid*(cb: GUICallback): bool {.inline.} =
  not isNil(cb.fn) and not isNil(cb.sender)

template valid*[T](cb: GUICallbackEX[T]): bool =
  GUICallback(cb).valid()

# ------------------------
# Signal Callback Dispatch
# ------------------------

proc call*(sig: GUISignal) =
  let
    kind = sig.kind
    cb = sig.cb
  # Select Callback kind
  case kind
  of sCallback:
    let fn = cast[GUICallbackProc](cb.fn)
    fn(cb.sender)
  of sCallbackEX:
    let fn = cast[GUICallbackProcEX](cb.fn)
    fn(cb.sender, addr sig.data)
  else: discard
