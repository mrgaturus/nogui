import ffi, locks
from typetraits import
  supportsCopyMem

type
  CoroCallbackProc* = NThreadProc
  CoroCallback* = NThreadTask
  CoroStage = proc(coro: ptr CoroBase)
    {.nimcall, gcsafe.}
  CoroBase = object
    man: ptr CoroManager
    prev, next: ptr CoroBase
    stage: CoroStage
    rc, skip: uint64
    # Coroutine Data
    mtx: Lock
    cond: Cond
    data: pointer
  CoroManager = object
    first, cursor: ptr CoroBase
    thr: Thread[ptr CoroManager]
    lane: NThreadLane
    # Main Loop Sleep
    mtx: Lock
    cond: Cond
  # -- Coroutine Generic --
  CoroutineManager* = ptr CoroManager
  CoroutineOpaque = distinct ptr CoroBase
  Coroutine*[T] = CoroutineOpaque
  CoroutineProc*[T] =
    proc(coro: Coroutine[T]) {.nimcall.}

# ------------------------------
# Coroutine Creation/Destruction
# ------------------------------

proc createCoroutine(stage0: CoroStage, size: int): ptr CoroBase =
  let
    chunk = allocShared0(CoroBase.sizeof + size)
    user = cast[uint64](chunk) + uint64(CoroBase.sizeof)
  # Define Coroutine Pointers
  result = cast[ptr CoroBase](chunk)
  result.data = cast[pointer](user)
  result.stage = stage0
  # Initialize Mutex
  initLock(result.mtx)
  initCond(result.cond)
  # Initialize Ref-Count
  inc(result.rc)

proc remove(coro: ptr CoroBase) =
  let
    man = coro.man
    prev = coro.prev
    next = coro.next
  # Detach From List
  if not isNil(prev):
    prev.next = coro.next
  if not isNil(next):
    next.prev = coro.prev
  if man.first == coro:
    man.first = coro.next
  # Remove Values
  coro.prev = nil
  coro.next = nil
  coro.man = nil
  # Remove Reference
  dec(coro.rc)

proc destroy(coro: ptr CoroBase) =
  deinitLock(coro.mtx)
  deinitCond(coro.cond)
  # Dealloc Coroutine
  deallocShared(coro)

# --------------------
# Coroutines Main Loop
# --------------------

proc dispatch(coro: ptr CoroBase): bool =
  acquire(coro.mtx)
  # Dispatch Coroutine
  let stage = coro.stage
  if coro.skip <= 0 and not isNil(stage):
    coro.stage = nil
    result = true
    stage(coro)
  # Check Coroutine Finalize
  if isNil(coro.stage):
    coro.remove()
    signal(coro.cond)
  # Release Coroutine
  let rc = coro.rc
  release(coro.mtx)
  if rc <= 0:
    coro.destroy()

proc worker(man: ptr CoroManager) =
  let brake = cast[ptr CoroBase](man)
  var passed: int
  # Step Coroutines
  while true:
    acquire(man.mtx)
    let cursor = man.cursor
    # Check Cursor Step
    if cursor == brake: break
    elif isNil(cursor):
      if passed == 0:
        wait(man.cond, man.mtx)
      # Reset Current Cursor
      if man.cursor != brake:
        man.cursor = man.first
        passed = 0
      # Skip Current
      release(man.mtx)
      continue
    # Dispatch Coroutine
    man.cursor = cursor.next
    if cursor.dispatch():
      inc(passed)
    # Release Mutex
    release(man.mtx)

# --------------------------------------
# Coroutine Manager Creation/Destruction
# --------------------------------------

proc createCoroutineManager*(): CoroutineManager =
  result = create(CoroManager)
  pool_lane_init(result.lane, result)
  # Create Syncronize Objects
  initLock(result.mtx)
  initCond(result.cond)
  # Create Coroutines Thread
  createThread(result.thr, worker, result)

proc destroyCoroutines(man: CoroutineManager) =
  var coro = man.first
  # Dealloc Coroutines
  while not isNil(coro):
    let coro0 = coro
    coro = coro.next
    coro0.destroy()
  # Stop Coroutine Main Loop
  let brake = cast[ptr CoroBase](man)
  man.cursor = brake

proc destroy*(man: CoroutineManager) =
  acquire(man.mtx)
  man.destroyCoroutines()
  signal(man.cond)
  release(man.mtx)
  # Dealloc Syncronize Object
  man.thr.joinThread()
  deinitLock(man.mtx)
  deinitCond(man.cond)
  # Dealloc Coroutine Manager
  pool_lane_destroy(man.lane)
  dealloc(man)

# ---------------------------
# Coroutine Control Reference
# ---------------------------

proc `=destroy`(coro: CoroutineOpaque) =
  let c = cast[ptr CoroBase](coro)
  if isNil(c): return
  # Decrement Reference
  acquire(c.mtx)
  dec(c.rc)
  let rc = c.rc
  release(c.mtx)
  # Destroy if not References
  if rc <= 0:
    c.destroy()

proc `=copy`(coro: var CoroutineOpaque, src: CoroutineOpaque) =
  let
    c0 = cast[ptr CoroBase](src)
    c1 = cast[ptr CoroBase](coro)
  if c0 == c1:
    return
  # Manipulate References
  `=destroy`(coro)
  acquire(c0.mtx)
  inc(c0.rc)
  release(c0.mtx)
  # Copy Coroutine Reference
  copyMem(addr coro, addr src,
    sizeof pointer)

proc `=sink`(coro: var CoroutineOpaque, src: CoroutineOpaque) =
  let
    c0 = cast[ptr CoroBase](src)
    c1 = cast[ptr CoroBase](coro)
  if c0 == c1:
    return
  # Copy Coroutine Reference
  `=destroy`(coro)
  copyMem(addr coro, addr src,
    sizeof pointer)

# -------------------------
# Coroutine Control Spawner
# -------------------------

template stage[T](fn: CoroutineProc[T]): CoroStage =
  when supportsCopyMem(T):
    {.gcsafe.}: cast[CoroStage](fn)
  else: {.error: "attempted use proc with a gc'd type".}

proc coroutine*[T](fn: CoroutineProc[T]): Coroutine[T] =
  let
    fn = stage[T](fn)
    coro = createCoroutine(fn, sizeof T)
  copyMem(addr result, addr coro, sizeof pointer)

proc spawn(man: CoroutineManager, coro: ptr CoroBase) =
  acquire(man.mtx)
  # Attach to Manager
  let first = man.first
  if not isNil(first):
    first.prev = coro
  coro.next = first
  coro.man = man
  # Reset Cursors
  man.first = coro
  man.cursor = coro
  # Increase Reference
  inc(coro.rc)
  signal(man.cond)
  release(man.mtx)

proc spawn*[T](man: CoroutineManager, coro: Coroutine[T]) =
  man.spawn cast[ptr CoroBase](coro)

# ----------------------
# Coroutine Control Flow
# ----------------------

proc send(coro: ptr CoroBase, cb: CoroCallback) =
  pool_lane_push(coro.man.lane, cb)

proc pass(coro: ptr CoroBase, stage: CoroStage) =
  coro.stage = stage

proc keep(coro: ptr CoroBase, stage: CoroStage) =
  coro.man.cursor = coro
  coro.stage = stage

proc cancel(coro: ptr CoroBase) =
  coro.stage = default(CoroStage)

proc pause(coro: ptr CoroBase) =
  coro.skip = high(uint64)

proc resume(coro: ptr CoroBase) =
  coro.skip = low(uint64)

proc wait(coro: ptr CoroBase) =
  acquire(coro.mtx)
  wait(coro.cond, coro.mtx)
  release(coro.mtx)

# ------------------------------
# Coroutine Control Flow Generic
# ------------------------------

template data*[T](coro: Coroutine[T]): ptr T =
  let base = cast[ptr CoroBase](coro)
  cast[ptr T](base.data)

template send*[T](coro: Coroutine[T], cb: CoroCallback) =
  send cast[ptr CoroBase](coro), cb

template keep*[T](coro: Coroutine[T], fn: CoroutineProc[T]) =
  keep cast[ptr CoroBase](coro), stage(fn)

template pass*[T](coro: Coroutine[T], fn: CoroutineProc[T]) =
  pass cast[ptr CoroBase](coro), stage(fn)

template cancel*[T](coro: Coroutine[T]) =
  cancel cast[ptr CoroBase](coro)

template pause*[T](coro: Coroutine[T]) =
  pause cast[ptr CoroBase](coro)

template resume*[T](coro: Coroutine[T]) =
  resume cast[ptr CoroBase](coro)

template wait*[T](coro: Coroutine[T]) =
  wait cast[ptr CoroBase](coro)

template lock*[T](coro: Coroutine[T], body: untyped) =
  block control:
    let base = cast[ptr CoroBase](coro)
    acquire(base.mtx); body
    release(base.mtx)

# ----------------------------------
# Coroutine Manager Callback Pumping
# ----------------------------------

iterator pump*(man: CoroutineManager): CoroCallback =
  let lane = addr man.lane
  while true:
    let task = pool_lane_steal(lane)
    if isNil(task.fn): break
    # Return Current Task
    yield task
