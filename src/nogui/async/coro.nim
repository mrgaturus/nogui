import ffi, locks
from typetraits import
  supportsCopyMem

type
  CoroCallbackProc* = NThreadProc
  CoroCallback* = NThreadTask
  # Coroutine Procedure Dispatch
  CoroProc = proc(coro: ptr CoroBase) {.nimcall, gcsafe.}
  CoroHandle = proc(coro: ptr CoroBase, signal: CoroSignal) {.nimcall, gcsafe.}
  CoroCancel = ref object of Defect
  CoroSignal* {.pure, size: 8.} = enum
    coroFinalize
    coroCancel
    coroStart
    coroPause
    coroResume
    coroRunning
    coroRelax
  # Coroutine Green Threads
  CoroVM = object
    state: NGreenState
    man: ptr CoroManager
    coro: ptr CoroBase
    # Coroutine List
    prev: ptr CoroVM
    next: ptr CoroVM
    free: ptr CoroVM
    # Coroutine Lock
    mtx: Lock
    cond: Cond
    # Coroutine Base
    signal: CoroSignal
    recv: CoroSignal
    fn0: CoroHandle
    fn: CoroProc
    stack: pointer
  CoroBase = object
    rc: uint64
    vm: ptr CoroVM
    man: ptr CoroManager
    mtx: Lock
    # Coroutine Data
    fn0: CoroHandle
    fn: CoroProc
    data: pointer
  CoroManager = object
    state: NGreenState
    thr: Thread[ptr CoroManager]
    lane: NThreadLane
    # Lock Manager
    mtx: Lock
    cond: Cond
    # Virtual Machine Manager
    free: ptr CoroVM
    first: ptr CoroVM
    last: ptr CoroVM
    signal: CoroSignal
    vmstack: uint64
  # -- Coroutine Generic --
  CoroutineManager* = ptr CoroManager
  CoroutineOpaque = distinct ptr CoroBase
  Coroutine*[T] = CoroutineOpaque
  CoroutineProc*[T] = proc(coro: Coroutine[T]) {.nimcall.}
  CoroutineHandle*[T] = proc(coro: Coroutine[T], signal: CoroSignal) {.nimcall.}

# ------------------------------
# Coroutine Creation/Destruction
# ------------------------------

proc createCoroutine(size: int): ptr CoroBase =
  let chunk = allocShared0(CoroBase.sizeof + size)
  let user = cast[uint64](chunk) + uint64(CoroBase.sizeof)
  # Define Coroutine Pointers
  result = cast[ptr CoroBase](chunk)
  result.data = cast[pointer](user)
  # Initialize Mutex
  initLock(result.mtx)
  inc(result.rc)

proc destroy(coro: ptr CoroBase) =
  deinitLock(coro.mtx)
  deallocShared(coro)

proc inc0ref(coro: ptr CoroBase) =
  discard atomicAddFetch(addr coro.rc, 1, ATOMIC_ACQUIRE)

proc dec0ref(coro: ptr CoroBase) =
  if atomicSubFetch(addr coro.rc, 1, ATOMIC_RELEASE) <= 0:
    coro.destroy()

# -----------------------------
# Green VM Creation/Destruction
# -----------------------------

proc createVM(man: ptr CoroManager): ptr CoroVM =
  let vmstack = max(man.vmstack, 4096)
  let chunk = allocShared(vmstack)
  zeroMem(chunk, sizeof CoroVM)
  # Initialize Virtual Machine
  result = cast[ptr CoroVM](chunk)
  result.man = man
  initLock(result.mtx)
  initCond(result.cond)
  # Initialize Stack Pointer
  let stack = cast[uint64](chunk) + vmstack
  result.stack = cast[pointer](stack)

proc destroy(vm: ptr CoroVM) =
  deinitLock(vm.mtx)
  deinitCond(vm.cond)
  deallocShared(vm)

proc detach(vm: ptr CoroVM) =
  let man = vm.man
  acquire(man.mtx)
  if isNil(vm.coro):
    release(man.mtx)
    return
  # Detach Execution
  if vm == man.first:
    man.first = vm.next
  if vm == man.last:
    man.last = vm.prev
  let prev = vm.prev
  let next = vm.next
  if not isNil(prev):
    prev.next = next
  if not isNil(next):
    next.prev = prev
  wasMoved(vm.next)
  wasMoved(vm.prev)
  # Detach Coroutine
  let coro = vm.coro
  wasMoved(coro.vm)
  wasMoved(coro.man)
  dec0ref(coro)
  wasMoved(vm.coro)
  wasMoved(vm.fn0)
  wasMoved(vm.fn)
  vm.free = man.free
  man.free = vm
  # Wake Waiting
  vm.signal = coroFinalize
  vm.recv = coroFinalize
  broadcast(vm.cond)
  release(man.mtx)

# ------------------------
# Coroutines VM: Main Loop
# ------------------------

proc payload(vm: ptr CoroVM) =
  let jmp = addr vm.man.state
  try: vm.fn(vm.coro)
  except CoroCancel:
    vm.signal = coroCancel
    green_jumpctx(jmp, 1)
  # Finalize Coroutine
  vm.signal = coroFinalize
  green_jumpctx(jmp, 1)

proc execute(man: ptr CoroManager, vm: ptr CoroVM): bool =
  result = false
  let frame = getFrameState()
  if vm.signal == coroStart:
    if green_setctx(addr man.state) != 0:
      setFrameState(frame)
      result = true
  # Execute Virtual Machine: Handle
  if vm.signal >= coroRunning:
    if result: return result
  elif not isNil(vm.fn0):
    if vm.signal != vm.recv:
      wasMoved(vm.coro.vm)
      # Handle Signal Changes
      vm.fn0(vm.coro, vm.signal)
      vm.coro.vm = vm
  # Execute Virtual Machine
  vm.recv = vm.signal
  case vm.signal
  of coroFinalize: vm.detach()
  of coroCancel:
    if not result and vm.recv != coroFinalize:
      green_jumpctx(addr vm.state, 1)
    else: vm.detach()
  of coroStart:
    vm.signal = coroRunning
    vm.recv = coroRunning
    let fn = cast[NGreenProc](payload)
    green_callctx(fn, vm, vm.stack)
  of coroPause: broadcast(vm.cond)
  of coroResume, coroRunning, coroRelax:
    vm.signal = coroRunning
    vm.recv = coroRunning
    green_jumpctx(addr vm.state, 1)

proc worker(man: ptr CoroManager) =
  var walk = man.first
  var count = 0
  while true:
    acquire(man.mtx)
    # Check Manager
    if isNil(walk):
      if count == 0:
        broadcast(man.cond)
        # Stop or Sleep Manager
        if man.signal == coroCancel:
          release(man.mtx); return
        wait(man.cond, man.mtx)
      walk = man.first
      count = 0
      # Wake Manager
      release(man.mtx)
      continue
    # Step Manager
    let vm = walk
    release(man.mtx)
    # Execute Virtual
    acquire(vm.mtx)
    walk = vm.next
    if man.execute(vm):
      inc(count)
      if vm.signal == coroRelax:
        walk = vm
    release(vm.mtx)

# ---------------------
# Coroutines VM: Signal
# ---------------------

proc virtual(coro: ptr CoroBase): bool =
  let vm = coro.vm
  if isNil(vm):
    return false
  # Check Virutal Stack
  let idx = cast[uint64](addr vm)
  let s1 = cast[uint64](vm.stack)
  let s0 = cast[uint64](vm)
  result = idx >= s0 and idx <= s1

proc escape(coro: ptr CoroBase) =
  let vm = coro.vm
  let frame = getFrameState()
  if green_setctx(addr vm.state) == 0:
    green_jumpctx(addr vm.man.state, 1)
  setFrameState(frame)
  # Check Coroutine Cancel
  if vm.signal == coroCancel:
    raise CoroCancel()

proc escape(coro: ptr CoroBase, sig: CoroSignal) {.inline.} =
  coro.vm.signal = sig
  coro.escape()

proc signal(coro: ptr CoroBase, sig: CoroSignal) {.inline.} =
  let vm = coro.vm
  if not isNil(vm):
    acquire(vm.mtx)
    vm.signal = sig
    release(vm.mtx)

# ---------------------------
# Coroutines VM: Control Flow
# ---------------------------

proc pass(coro: ptr CoroBase) =
  if coro.virtual():
    coro.escape()

proc relax(coro: ptr CoroBase) =
  if coro.virtual():
    coro.escape(coroRelax)

proc pause(coro: ptr CoroBase) =
  if coro.virtual():
    coro.escape(coroPause)
  else: coro.signal(coroPause)

proc resume(coro: ptr CoroBase) =
  if not coro.virtual():
    let vm = coro.vm
    if isNil(vm): return
    acquire(vm.mtx)
    # Resume Only when Paused
    if vm.recv == coroPause:
      acquire(vm.man.mtx)
      vm.signal = coroResume
      signal(vm.man.cond)
      release(vm.man.mtx)
    release(vm.mtx)

proc cancel(coro: ptr CoroBase) =
  if coro.virtual():
    raise CoroCancel()
  coro.signal(coroCancel)

proc send(coro: ptr CoroBase, cb: CoroCallback) =
  let man = coro.man
  if isNil(man): return
  pool_lane_push(man.lane, cb)

proc wait(coro: ptr CoroBase) =
  let vm = coro.vm
  if isNil(vm) or coro.virtual():
    return
  # Lock Finalized
  acquire(vm.mtx)
  if vm.coro == coro and
    vm.recv != coroPause:
      wait(vm.cond, vm.mtx)
  release(vm.mtx)

# ---------------------------
# Coroutines: Reference Count
# ---------------------------

proc `=destroy`(coro: CoroutineOpaque) =
  let c = cast[ptr CoroBase](coro)
  if not isNil(c):
    c.dec0ref()

proc `=copy`(coro: var CoroutineOpaque, src: CoroutineOpaque) =
  let
    c0 = cast[ptr CoroBase](src)
    c1 = cast[ptr CoroBase](coro)
  if c0 == c1: return
  # Manipulate References
  `=destroy`(coro)
  c0.inc0ref()
  # Copy Coroutine Reference
  cast[ptr pointer](addr coro)[] =
    cast[pointer](src)

proc `=sink`(coro: var CoroutineOpaque, src: CoroutineOpaque) =
  let
    c0 = cast[ptr CoroBase](src)
    c1 = cast[ptr CoroBase](coro)
  if c0 == c1: return
  # Copy Coroutine Reference
  `=destroy`(coro)
  cast[ptr pointer](addr coro)[] =
    cast[pointer](src)

# --------------------------------------
# Coroutine Manager Creation/Destruction
# --------------------------------------

proc createCoroutineManager*(vmstack: uint64 = 65536): CoroutineManager =
  result = create(CoroManager)
  result.signal = coroRunning
  result.vmstack = vmstack
  # Create Coroutine Thread
  initLock(result.mtx)
  initCond(result.cond)
  pool_lane_init(result.lane, result)
  createThread(result.thr, worker, result)

proc destroyCoros(man: CoroutineManager) =
  var vm = man.free
  while not isNil(vm):
    let vm0 = vm
    vm = vm.next
    vm0.destroy()
  # Cancel Coroutines
  vm = man.first
  while not isNil(vm):
    vm.coro.cancel()
    vm = vm.next
  signal(man.cond)
  wait(man.cond, man.mtx)
  # Destroy Stacks
  vm = man.first
  while not isNil(vm):
    let vm0 = vm
    vm = vm.next
    vm0.destroy()

proc destroy*(man: CoroutineManager) =
  acquire(man.mtx)
  man.signal = coroCancel
  man.destroyCoros()
  release(man.mtx)
  # Destroy Thread
  man.thr.joinThread()
  deinitLock(man.mtx)
  deinitCond(man.cond)
  # Dealloc Coroutine Manager
  pool_lane_destroy(man.lane)
  dealloc(man)

# --------------------------
# Coroutine Manager: Spawner
# --------------------------

proc coroutine*(T: typedesc): Coroutine[T] =
  when supportsCopyMem(T):
    {.gcsafe.}:
      let coro = createCoroutine(sizeof T)
      copyMem(addr result, addr coro, sizeof pointer)
  else: {.error: "attempted use a gc'd type".}

proc setProc*[T](coro: Coroutine[T], fn: CoroutineProc[T]) =
  {.gcsafe.}: cast[ptr CoroBase](coro).fn = cast[CoroProc](fn)

proc setHandle*[T](coro: Coroutine[T], fn: CoroutineHandle[T]) =
  {.gcsafe.}: cast[ptr CoroBase](coro).fn0 = cast[CoroHandle](fn)

proc spawn(man: CoroutineManager, coro: ptr CoroBase) =
  var vm = coro.vm
  if isNil(coro.fn): return
  elif not isNil(vm):
    acquire(vm.mtx)
    if vm.coro == coro:
      release(vm.mtx); return
    release(vm.mtx)
  # Configure Virtual Machine
  acquire(man.mtx)
  let last = man.last
  if not isNil(man.free):
    vm = man.free
    man.free = vm.free
  else: vm = createVM(man)
  vm.signal = coroStart
  vm.recv = coroFinalize
  # Configure Coroutine
  vm.coro = coro
  inc0ref(coro)
  vm.fn0 = coro.fn0
  vm.fn = coro.fn
  # Attach Virtual
  if isNil(man.first):
    man.first = vm
  if not isNil(last):
    last.next = vm
    vm.prev = last
  man.last = vm
  # Attach Manager
  coro.vm = vm
  coro.man = man
  signal(man.cond)
  release(man.mtx)

proc spawn*[T](man: CoroutineManager, coro: Coroutine[T]) =
  man.spawn cast[ptr CoroBase](coro)

# -------------------------
# Coroutine Manager: Public
# -------------------------

# -- Coroutine Control Flow --
template pass*[T](coro: Coroutine[T]) =
  pass cast[ptr CoroBase](coro)

template relax*[T](coro: Coroutine[T]) =
  relax cast[ptr CoroBase](coro)

template pause*[T](coro: Coroutine[T]) =
  pause cast[ptr CoroBase](coro)

template resume*[T](coro: Coroutine[T]) =
  resume cast[ptr CoroBase](coro)

template cancel*[T](coro: Coroutine[T]) =
  cancel cast[ptr CoroBase](coro)

# -- Coroutine Data --
template data*[T](coro: Coroutine[T]): ptr T =
  let base = cast[ptr CoroBase](coro)
  cast[ptr T](base.data)

template send*[T](coro: Coroutine[T], cb: CoroCallback) =
  send cast[ptr CoroBase](coro), cb

template wait*[T](coro: Coroutine[T]) =
  wait cast[ptr CoroBase](coro)

# -- Coroutine Locking --
template mutexAcquire*[T](coro: Coroutine[T]) =
  acquire cast[ptr CoroBase](coro).mtx

template mutexRelease*[T](coro: Coroutine[T]) =
  release cast[ptr CoroBase](coro).mtx

template lock*[T](coro: Coroutine[T], body: untyped) =
  block control:
    let base = cast[ptr CoroBase](coro)
    acquire(base.mtx); body
    release(base.mtx)

# -----------------------------
# Coroutine Manager: Operations
# -----------------------------

proc wait*(man: CoroutineManager) =
  acquire(man.mtx)
  signal(man.cond)
  wait(man.cond, man.mtx)
  release(man.mtx)

proc cancel*(man: CoroutineManager) =
  acquire(man.mtx)
  var vm = man.first
  # Send Cancel to Coros
  while not isNil(vm):
    vm.coro.cancel()
    vm = vm.next
  signal(man.cond)
  release(man.mtx)

iterator pump*(man: CoroutineManager): CoroCallback =
  let lane = addr man.lane
  while true:
    let task = pool_lane_steal(lane)
    if isNil(task.fn): break
    # Return Current Task
    yield task
