# TODO: unify with event

type
  # GUI Signal Private
  SKind* = enum
    sCallback
    sCallbackEX
    sWidget
    sWindow
  WidgetSignal* = enum
    msgDirty, msgFocus
    msgCheck, msgClose
    # Widget Window Open
    msgFrame, msgPopup, msgTooltip
  WindowSignal* = enum
    msgOpenIM
    msgCloseIM
    # Remove State
    msgUnfocus
    msgUnhover
    # Close Program
    msgTerminate
  Signal = object
    next: GUISignal
    # Signal or Callback
    case kind*: SKind
    of sCallback, sCallbackEX:
      cb*: GUICallback
    of sWidget:
      id*: GUITarget
      msg*: WidgetSignal
    of sWindow:
      wsg*: WindowSignal
    # Signal Data
    data*: GUIOpaque
  # Signal Generic Data
  GUITarget* = distinct pointer
  GUIOpaque* = object
  # GUI Callbacks Procs
  GUICallbackProc =
    proc(sender, state: pointer) {.nimcall.}
  GUICallbackProcEX = # With Parameter
    proc(sender, state, extra: pointer) {.nimcall.}
  # GUI Callbacks
  GUICallback* = object
    sender, fn: pointer
  GUICallbackEX*[T] = 
    distinct GUICallback
  # GUI Signal and Queue
  GUISignal* = ptr Signal
  Queue = object
    state: pointer
    # Queue Endpoints
    back, front: GUISignal
  GUIQueue* = ptr Queue
# Global GUI Queue
var opaque: GUIQueue

proc newGUIQueue*(state: pointer): GUIQueue =
  result = create(Queue)
  # Set Global State
  result.state = state
  # GUI Queue Global
  opaque = result

proc newSignal(size: Natural = 0): GUISignal {.inline.} =
  result = cast[GUISignal](alloc0(Signal.sizeof + size))
  # This is Latest
  result.next = nil

# --------------------
# SIGNAL RUNTIME PROCS
# --------------------

proc push(queue: GUIQueue, signal: GUISignal) =
  if queue.front.isNil:
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

# ---------------------------
# SIGNAL UNSAFE PUSHING PROCS
# ---------------------------

proc pushSignal*(id: GUITarget, msg: WidgetSignal) =
  assert(not cast[pointer](id).isNil)
  # Get Queue Pointer from Global
  let 
    queue = opaque
    signal = newSignal()
  # Widget Signal Kind
  signal.kind = sWidget
  signal.id = id
  signal.msg = msg
  # Add new signal to Front
  queue.push(signal)

proc pushSignal(msg: WindowSignal, data: pointer, size: Natural) =
  # Get Queue Pointer from Global
  let
    queue = opaque
    signal = newSignal(size)
  # Window Signal Kind
  signal.kind = sWindow
  signal.wsg = msg
  # Copy Optionally Data
  if size > 0 and not isNil(data):
    copyMem(addr signal.data, data, size)
  # Add new signal to Front
  queue.push(signal)

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
  if isNil(cb.fn) and isNil(data): return
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

# ------------------------
# UNSAFE CALLBACK CREATION
# ------------------------

template unsafeCallback*(self: pointer, call: proc): GUICallback =
  GUICallback(
    sender: self, 
    fn: cast[pointer](call)
  )

template unsafeCallbackEX*[T](self: pointer, call: proc): GUICallbackEX[T] =
  GUICallbackEX[T](unsafeCallback(self, call))

# ----------------------------------
# GUI WIDGET SIGNAL PUSHER TEMPLATES
# ----------------------------------

template pushSignal*(msg: WindowSignal, data: typed) =
  pushSignal(msg, addr data, sizeof data)

template pushSignal*(msg: WindowSignal) =
  pushSignal(msg, nil, 0)

# ------------------------------------
# GUI CALLBACK SIGNAL PUSHER TEMPLATES
# ------------------------------------

template push*(cb: GUICallback) =
  pushCallback(cb)

template push*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).pushCallback(addr data, sizeof T)

proc valid*(cb: GUICallback): bool {.inline.} =
  not isNil(cb.fn) and not isNil(cb.sender)

template valid*[T](cb: GUICallbackEX[T]): bool =
  GUICallback(cb).valid

# --------------------------
# GUI CALLBACK FORCE CALLERS
# --------------------------

proc force*(cb: GUICallback) =
  let fn = cast[GUICallbackProc](cb.fn)
  # Execute if is Valid
  if not isNil(fn):
    fn(cb.sender, opaque.state)

proc forceEX(cb: GUICallback, data: pointer) =
  let fn = cast[GUICallbackProcEX](cb.fn)
  # Execute if is Valid
  if not (fn.isNil or data.isNil):
    fn(cb.sender, opaque.state, data)

template force*[T](cb: GUICallbackEX[T], data: ptr T) =
  forceEX(cb.GUICallback, data)

# ---------------------------------
# GUI SIGNAL DATA POINTER CONVERTER
# ---------------------------------

proc call*(sig: GUISignal) =
  let
    kind = sig.kind
    cb = sig.cb
    # Current Global State
    state = opaque.state
  # Select Callback kind
  case kind
  of sCallback:
    let fn = cast[GUICallbackProc](cb.fn)
    fn(cb.sender, state)
  of sCallbackEX:
    let fn = cast[GUICallbackProcEX](cb.fn)
    fn(cb.sender, state, addr sig.data)
  else: discard
