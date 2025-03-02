import ffi, locks, cpuinfo
from typetraits import
  supportsCopyMem

type
  NThreadGenericProc[T] = proc (data: ptr T) {.nimcall.}
  NThread = Thread[ptr NThreadLane]
  # Lock-free Thread Pool
  ThreadPool = object
    status {.align: 64.}: NThreadStatus
    works {.align: 64.}: NThreadCounter 
    awake {.align: 64.}: NThreadCounter
    # Thread Sleep
    latch: Lock
    mtx: Lock
    cond: Cond
    # Thread Count
    count, idx: int64
    threads: seq[NThread]
    lanes: seq[NThreadLane]
  NThreadPool* = ptr ThreadPool

# ----------------------------
# Thread Lane Worker Procedure
# ----------------------------

proc victim(lane: ptr NThreadLane): ptr NThreadLane =
  var idx = lane.rng
  # Calculate xorshift Random Number
  idx = idx xor idx shl 13
  idx = idx xor idx shr 7
  idx = idx xor idx shl 17
  lane.rng = idx
  # Choose Lane Victim
  let pool = cast[NThreadPool](lane.opaque)
  idx = idx mod uint64(pool.count)
  result = addr pool.lanes[idx]

proc consume(lane: ptr NThreadLane): NThreadTask =
  result = pool_lane_steal(lane)
  if not isNil(result.fn):
    return result
  # Try Steal from Other Lane
  let v = lane.victim()
  result = pool_lane_steal(v)

proc worker(lane: ptr NThreadLane) =
  let pool = cast[NThreadPool](lane.opaque)
  pool_status_inc(pool.awake)
  # Thread Worked Main Loop
  while true:
    case pool_status_get(pool.status):
    of thrWorking:
      let task = lane.consume()
      # Dispatch Thread Task
      if not isNil(task.fn):
        task.fn(task.data)
        pool_status_dec(pool.works)
        continue
    # Thread Sleeping Control
    of thrSleep:
      if tryAcquire(pool.mtx):
        pool_status_dec(pool.awake)
        wait(pool.cond, pool.mtx)
        release(pool.mtx)
        pool_status_inc(pool.awake)
    of thrTerminate:
      break
    # Relax CPU Scheduler
    cpuRelax()

# ------------------------
# Thread Pool Manipulation
# ------------------------

proc start*(pool: NThreadPool) =
  acquire(pool.latch)
  pool_status_set(pool.status, thrWorking)
  # Wake Thread Workers
  acquire(pool.mtx)
  broadcast(pool.cond)
  release(pool.mtx)

proc push(pool: NThreadPool, fn: NThreadProc, data: pointer) =
  var task: NThreadTask
  # Initialize Task Values
  task.fn = fn
  task.data = data
  # Get Current Thread ID
  let 
    core = pool.idx
    count = pool.count
  # Push Current Lane
  pool_status_inc(pool.works)
  pool_lane_push(pool.lanes[core], task)
  pool.idx = (core + 1) mod count

proc spawn*[T: object](pool: NThreadPool, fn: NThreadGenericProc[T], data: ptr T) {.inline.} =
  when supportsCopyMem(T):
    # Bypass GC Safe Check
    {.gcsafe.}:
      let fn0 = cast[NThreadProc](fn)
      push(pool, fn0, data)
  else: {.error: "attempted spawn proc with a gc'd type".}

proc sync*(pool: NThreadPool) =
  while pool_status_get(pool.works) > 0:
    cpuRelax() # Wait all Works Finalized

proc cancel*(pool: NThreadPool) =
  pool_status_set(pool.status, thrSleep)
  while pool_status_get(pool.awake) > 0:
    cpuRelax()
  # Reset Pool Lanes and Counter
  for lane in mitems(pool.lanes):
    pool_lane_reset(lane)
  pool_status_reset(pool.works)
  pool_status_set(pool.status, thrWorking)
  # Resume Thread Workers
  acquire(pool.mtx)
  broadcast(pool.cond)
  release(pool.mtx)

proc stop*(pool: NThreadPool) =
  pool_status_set(pool.status, thrSleep)
  release(pool.latch)

# --------------------------------
# Thread Pool Creation/Destruction
# --------------------------------

proc createThreadPool*(): NThreadPool =
  result = create(ThreadPool)
  pool_status_set(result.status, thrSleep)
  # Create Pool Sleep
  initLock(result.latch)
  initLock(result.mtx)
  initCond(result.cond)
  # Create Worker Threads
  let cores = countProcessors()
  setLen(result.lanes, cores)
  setLen(result.threads, cores)
  # Initialize Threads
  result.count = cores
  for core in 0 ..< cores:
    let
      lane = addr result.lanes[core]
      thr = addr result.threads[core]
    # Create Thread and Pin to CPU
    pool_lane_init(lane[], result)
    thr[].createThread(worker, lane)
    thr[].pinToCpu(core)

proc terminate(pool: NThreadPool) =
  pool_status_set(pool.status, thrTerminate)
  # Wake-up Threads if are Sleep
  acquire(pool.mtx)
  broadcast(pool.cond)
  release(pool.mtx)
  # Wait Threads Finished
  for thr in mitems(pool.threads):
    thr.joinThread()

proc destroy*(pool: NThreadPool) =
  pool.terminate()
  # Destroy Pool Sleep
  deinitLock(pool.latch)
  deinitLock(pool.mtx)
  deinitCond(pool.cond)
  # Destroy Lane Data
  for lane in mitems(pool.lanes):
    pool_lane_destroy(lane)
  # Dealloc Thread Pool
  `=destroy`(pool.threads)
  `=destroy`(pool.lanes)
  dealloc(pool)

# -----------------------
# Thread Pool Information
# -----------------------

proc cores*(pool: NThreadPool): int {.inline.} =
  cast[int](pool.count)

proc pending*(pool: NThreadPool): bool {.inline.} =
  pool_status_get(pool.works) > 0

proc locked*(pool: NThreadPool): bool {.inline.} =
  pool_status_get(pool.status) == thrWorking
