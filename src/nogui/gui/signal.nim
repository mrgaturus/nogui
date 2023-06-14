# GUI Signal/Callback Queue
from config import opaque

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
  GUICallback = object
    sender, fn: pointer
  GUICallbackEX[T] = 
    distinct GUICallback
  # GUI Signal and Queue
  GUISignal* = ptr Signal
  GUIQueue* = ref object
    back, front: GUISignal

proc newGUIQueue*(global: pointer): GUIQueue =
  new result # Create Object
  opaque.queue = cast[pointer](result)
  # Define User Global Pointer
  opaque.user = global

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

# ---------------------------
# SIGNAL UNSAFE PUSHING PROCS
# ---------------------------

proc pushSignal*(id: GUITarget, msg: WidgetSignal) =
  assert(not cast[pointer](id).isNil)
  # Get Queue Pointer from Global
  var queue = cast[GUIQueue](opaque.queue)
  let signal = newSignal()
  # Widget Signal Kind
  signal.kind = sWidget
  signal.id = id
  signal.msg = msg
  # Add new signal to Front
  queue.push(signal)

proc pushSignal(msg: WindowSignal, data: pointer, size: Natural) =
  # Get Queue Pointer from Global
  var queue = cast[GUIQueue](opaque.queue)
  let signal = newSignal(size)
  # Window Signal Kind
  signal.kind = sWindow
  signal.wsg = msg
  # Copy Optionally Data
  if size > 0 and not isNil(data):
    copyMem(addr signal.data, data, size)
  # Add new signal to Front
  queue.push(signal)

proc pushCallback(cb: GUICallback) =
  assert(not cb.fn.isNil)
  # Get Queue Pointer from Global
  var queue = cast[GUIQueue](opaque.queue)
  let signal = newSignal()
  # Assign Callback
  signal.kind = sCallback
  signal.cb = cb
  # Add new signal to Front
  queue.push(signal)

proc pushCallback(cb: GUICallback, data: pointer, size: Natural) =
  assert(not isNil cb.fn)
  assert(not isNil data)
  # Get Queue Pointer from Global
  var queue = cast[GUIQueue](opaque.queue)
  let signal = newSignal(size)
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

template unsafeCallback*(sender: pointer, cb: proc): GUICallback =
  GUICallback(
    sender: sender, 
    cb = cast[pointer](cb)
  )

template unsafeCallbackEX*[T](sender: pointer, cb: proc): GUICallbackEX[T] =
  GUICallbackEX[T](
    sender: sender, 
    cb = cast[pointer](cb)
  )

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

# ---------------------------------
# GUI SIGNAL DATA POINTER CONVERTER
# ---------------------------------

proc call*(sig: GUISignal) =
  let
    kind = sig.kind
    cb = sig.cb
  # Select Callback kind
  case kind
  of sCallback:
    let fn = cast[GUICallbackProc](cb.fn)
    fn(cb.sender, opaque.user)
  of sCallbackEX:
    let fn = cast[GUICallbackProcEX](cb.fn)
    fn(cb.sender, opaque.user, addr sig.data)
  else: discard

template convert*(data: GUIOpaque, t: type): ptr t =
  cast[ptr t](addr data)
