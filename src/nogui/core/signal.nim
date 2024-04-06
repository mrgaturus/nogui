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
    back, front: GUISignal
  GUIQueue* = ptr Queue
# Global GUI Queue
var opaque: GUIQueue

proc newGUIQueue*(): GUIQueue =
  result = create(Queue)
  # GUI Queue Global
  opaque = result

proc newSignal(size: Natural = 0): GUISignal {.inline.} =
  result = cast[GUISignal](alloc0(Signal.sizeof + size))
  # This is Latest
  result.next = nil

# -------------------------
# Signal Queue Manipulation
# -------------------------

proc push(queue: GUIQueue, signal: GUISignal) =
  if isNil(queue.front):
    queue.back = signal
    queue.front = signal
  else:
    queue.front.next = signal
    queue.front = signal

iterator poll*(queue: GUIQueue): GUISignal =
  var signal = queue.back
  while signal != nil:
    yield signal
    # Use back as prev
    queue.back = signal
    signal = signal.next
    # dealloc prev
    dealloc(queue.back)
  queue.back = nil
  queue.front = nil

proc dispose*(queue: GUIQueue) =
  var signal = queue.back
  while signal != nil:
    # Use back as prev
    queue.back = signal
    signal = signal.next
    # dealloc prev
    dealloc(queue.back)
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

# -----------------------
# Signal Callback Sending
# -----------------------

proc pushCallback(cb: GUICallback) =
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

proc pushCallback(cb: GUICallback, data: pointer, size: Natural) =
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

# -----------------------
# Signal Callback Sending
# -----------------------

template send*(cb: GUICallback) =
  pushCallback(cb)

template send*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).pushCallback(addr data, sizeof T)

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
