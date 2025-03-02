from ../native/ffi import GUINative
import ../core/callback
import coro, pool

type
  GUIAsync = object
    coros: CoroutineManager
    pool: NThreadPool

proc `=destroy`(man: GUIAsync) =
  if not isNil(man.coros):
    destroy(man.coros)
  # Dealloc Thread Pool
  if not isNil(man.pool):
    destroy(man.pool)

# ------------------------
# Async Objects: On Demand
# ------------------------

var man0: GUIAsync
proc getCoros*(): CoroutineManager =
  if isNil(man0.coros):
    man0.coros = createCoroutineManager()
  result = man0.coros

proc getPool*(): NThreadPool =
  if isNil(man0.pool):
    man0.pool = createThreadPool()
  result = man0.pool

# ----------------------
# Async Objects: Prelude
# ----------------------

export coro except
  createCoroutineManager,  
  destroy,
  spawn,
  pump

export pool except
  createThreadPool,
  destroy

# -------------------------
# Async Coroutine: Callback
# -------------------------

template spawn*[T](coro: Coroutine[T]) =
  let coros = getCoros()
  coros.spawn(coro)

converter coro*(cb: GUICallback): CoroCallback =
  cast[CoroCallback](cb)

proc nogui_coroutine_pump*(native: ptr GUINative) =
  let coros {.cursor.} = man0.coros
  if isNil(coros): return
  # Pump Async Callbacks
  for cb in coros.pump():
    send cast[GUICallback](cb)
