import ../native/ffi

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
    # Widget Signal
    sWidget
  WidgetSignal* = enum
    wsLayout
    wsFocus
    # Toplevel
    wsOpen
    wsClose
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
    # Signal Data
    data*: GUIOpaque
  # Signal Pointer
  GUISignal* = ptr Signal
  GUISending = object
    cb: ptr GUINativeCallback
    data: GUISignal
# Global GUI Queue
var queue: ptr GUINativeQueue

# --------------------
# Signal Queue Sending
# --------------------

proc useQueue*(queue: ptr GUINativeQueue) =
  # Queue Callback was defined by Window
  signal.queue = queue

proc createSignal(bytes = 0): GUISending =
  let
    cb0 = addr queue.cb_signal
    # Allocate Queue Signal
    size = int32(Signal.sizeof + bytes)
    cb = nogui_cb_create(size)
    data = nogui_cb_data(cb)
  # Configure Callback Proc
  cb.self = cb0.self
  cb.fn = cb0.fn
  # Return Sending
  result.cb = cb
  result.data = cast[GUISignal](data)
  zeroMem(data, Signal.sizeof)

# ----------------------------
# Signal Widget Signal Sending
# ----------------------------

proc signal(target: GUITarget, ws: WidgetSignal): GUISending =
  result = createSignal()
  let s = result.data
  # Define Signal Properties
  s.kind = sWidget
  s.target = target
  s.ws = ws

proc send*(target: GUITarget, ws: WidgetSignal) =
  assert(not cast[pointer](target).isNil)
  let s = signal(target, ws)
  # Send Created Callback
  nogui_queue_push(queue, s.cb)

proc relax*(target: GUITarget, ws: WidgetSignal) =
  assert(not cast[pointer](target).isNil)
  let s = signal(target, ws)
  # Send Created Callback
  nogui_queue_relax(queue, s.cb)

# ------------------------------
# Signal Callback Signal Sending
# ------------------------------

proc signal(cb: GUICallback): GUISending =
  result = createSignal()
  let s = result.data
  # Define Signal Properties
  s.kind = sCallback
  s.cb = cb

proc send*(cb: GUICallback) =
  if isNil(cb.fn): return
  let s = signal(cb)
  # Send Created Callback
  nogui_queue_push(queue, s.cb)

proc relax*(cb: GUICallback) =
  if isNil(cb.fn): return
  let s = signal(cb)
  # Send Created Callback
  nogui_queue_relax(queue, s.cb)

# -----------------------------
# Signal Callback Extra Sending
# -----------------------------

proc signal(cb: GUICallback, data: pointer, size: Natural): GUISending =
  result = createSignal()
  let s = result.data
  # Define Signal Properties
  s.kind = sCallbackEX
  s.cb = cb
  # Copy Optionally Data
  if size > 0 and not isNil(data):
    copyMem(addr s.data, data, size)

proc send(cb: GUICallback, data: pointer, size: Natural) =
  if isNil(cb.fn) or isNil(data): return
  let s = signal(cb, data, size)
  # Send Created Callback
  nogui_queue_push(queue, s.cb)

proc relax(cb: GUICallback, data: pointer, size: Natural) =
  if isNil(cb.fn) or isNil(data): return
  let s = signal(cb, data, size)
  # Send Created Callback
  nogui_queue_relax(queue, s.cb)

template send*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).send(addr data, sizeof T)

template relax*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).relax(addr data, sizeof T)

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
