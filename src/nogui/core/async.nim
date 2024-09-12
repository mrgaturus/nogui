from ../native/ffi import GUINative
import ../async/[coro, pool]
import callback

type
  GUIAsync = object
    c0: CoroutineManager
    p0: NThreadPool
# Global Async Manager
var async0: GUIAsync

proc `=destroy`(async0: GUIAsync) =
  if not isNil(async0.c0):
    destroy(async0.c0)
  # Dealloc Thread Pool
  if not isNil(async0.p0):
    destroy(async0.p0)

# -----------------------
# Async Objects on Demand
# -----------------------

proc coros(async: ptr GUIAsync): CoroutineManager =
  if isNil(async.c0):
    async.c0 = createCoroutineManager()
  # Return Coroutine Manager
  result = async.c0

proc pool*(async: ptr GUIAsync): NThreadPool =
  if isNil(async.p0):
    async.p0 = createThreadPool()
  # Return Thread Pool
  result = async.p0

proc getAsync*(): ptr GUIAsync {.inline.} =
  addr async0

# -----------------------
# Async Coroutine Manager
# -----------------------

template spawn*[T](coro: Coroutine[T]) =
  let coros = coros(addr async0)
  coros.spawn(coro)

proc swap(cb: CoroCallback): CoroCallback =
  result.fn = cast[CoroCallbackProc](cb.data)
  result.data = cast[pointer](cb.fn)

converter coro*(cb: GUICallback): CoroCallback =
  cast[CoroCallback](cb).swap()

proc nogui_coroutine_pump*(native: ptr GUINative) =
  let coro {.cursor.} = async0.c0
  if isNil(coro): return
  # Pump Async Callbacks
  for cb in coro.pump():
    send cast[GUICallback](cb.swap)

# -------------------
# Async Module Export
# -------------------

export coro except
  createCoroutineManager,  
  destroy,
  spawn,
  pump

export pool except
  createThreadPool,
  destroy
