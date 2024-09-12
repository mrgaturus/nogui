import ../native/ffi
import ../async/coro

type
  # Callback Generic Data
  GUIOpaque = object
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
  Sending = object
    bytes: int
    # Callback Data
    cb: GUICallback
    data: GUIOpaque
  GUISending = ptr Sending
  # GUI Native Sender
  GUIMessage = object
    cb: ptr GUINativeCallback
    send: GUISending
  GUIMail = object
    fn: GUINativeProc
    queue: ptr GUINativeQueue
    coros: CoroutineManager
# GUI Native Queue
var mail: GUIMail

# ----------------------------
# Signal Queue Message Sending
# ----------------------------

proc dispatch(self: pointer, send: GUISending) {.noconv.} =
  let cb = send.cb
  # Simple Callback
  if send.bytes == 0:
    let fn = cast[GUICallbackProc](cb.fn)
    fn(cb.sender)
  # Data Callback
  elif send.bytes > 0:
    let fn = cast[GUICallbackProcEX](cb.fn)
    fn(cb.sender, addr send.data)

proc message(bytes = 0): GUIMessage =
  let
    size = int32(Sending.sizeof + bytes)
    cb = nogui_cb_create(size)
    data = nogui_cb_data(cb)
  # Configure Native Callback
  cb.self = addr mail
  cb.fn = mail.fn
  # Configure Message
  result.cb = cb
  result.send = cast[GUISending](data)
  # Clear Sending Data
  zeroMem(data, Sending.sizeof)

# ----------------------
# Signal Queue Messenger
# ----------------------

proc createMessenger*(native: ptr GUINative) =
  mail.fn = cast[GUINativeProc](dispatch)
  mail.queue = nogui_native_queue(native)
  mail.coros = createCoroutineManager()

proc destroyMessenger*(native: ptr GUINative) =
  if mail.queue == nogui_native_queue(native):
    destroy(mail.coros)

proc nogui_coroutine_pump*(native: ptr GUINative) =
  let queue = mail.queue
  # Pump Coroutine Callbacks
  for cb in pump(mail.coros):
    var msg = message()
    # Define Callback Data
    let c = addr msg.send.cb
    c.fn = cast[GUICallbackProc](cb.fn)
    c.sender = cb.data
    # Push Callback to Queue
    nogui_queue_push(queue, msg.cb)

# ------------------------
# Callback Message Sending
# ------------------------

proc message(cb: GUICallback): GUIMessage =
  result = message()
  # Define Simple Callback
  let s = result.send
  s.cb = cb

proc send*(cb: GUICallback) =
  if isNil(cb.fn): return
  let msg = message(cb)
  # Send Created Callback
  nogui_queue_push(mail.queue, msg.cb)

proc relax*(cb: GUICallback) =
  if isNil(cb.fn): return
  let msg = message(cb)
  # Send Created Callback
  nogui_queue_relax(mail.queue, msg.cb)

# ------------------------------
# Callback Extra Message Sending
# ------------------------------

proc message(cb: GUICallback, data: pointer, size: Natural): GUIMessage =
  result = message(size)
  # Define Data Callback
  let s = result.send
  s.cb = cb
  s.bytes = size
  # Copy Optionally Data
  if size > 0 and not isNil(data):
    copyMem(addr s.data, data, size)

proc send(cb: GUICallback, data: pointer, size: Natural) =
  if isNil(cb.fn) or isNil(data): return
  let msg = message(cb, data, size)
  # Send Created Callback
  nogui_queue_push(mail.queue, msg.cb)

proc relax(cb: GUICallback, data: pointer, size: Natural) =
  if isNil(cb.fn) or isNil(data): return
  let msg = message(cb, data, size)
  # Send Created Callback
  nogui_queue_relax(mail.queue, msg.cb)

template send*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).send(addr data, sizeof T)

template relax*[T](cb: GUICallbackEX[T], data: sink T) =
  GUICallback(cb).relax(addr data, sizeof T)

# ------------------------
# Callback Message Forcing
# ------------------------

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

# ------------------------
# Callback Unsafe Creation
# ------------------------

template unsafeCallback*(self: pointer, call: proc): GUICallback =
  GUICallback(sender: self, fn: cast[pointer](call))

template unsafeCallbackEX*[T](self: pointer, call: proc): GUICallbackEX[T] =
  GUICallbackEX[T](unsafeCallback(self, call))

# --------------------------
# Callback Unsafe Validation
# --------------------------

proc valid*(cb: GUICallback): bool {.inline.} =
  not isNil(cb.fn) and not isNil(cb.sender)

template valid*[T](cb: GUICallbackEX[T]): bool =
  GUICallback(cb).valid()

# --------------------------
# Callback Coroutine Sending
# --------------------------

converter coro*(cb: GUICallback): CoroCallback =
  result.fn = cast[CoroCallbackProc](cb.fn)
  result.data = cb.sender

template spawn*[T](coro: Coroutine[T]) =
  spawn(mail.coros, coro)
