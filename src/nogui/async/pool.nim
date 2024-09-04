from typetraits import
  supportsCopyMem
# Multi-Threading
import locks
import cpuinfo

# Avoid import os.parentDir
# TODO: rewrite c files to nimskull
proc includePath(): string {.compileTime.} =
  result = currentSourcePath()
  var l = result.len
  # Remove File Name
  while l > 0:
    let c = result[l - 1]
    if c == '/' or c == '\\':
      break
    # Next Char
    dec(l)
  # Remove Chars
  result.setLen(l)

# ----------------------
# Thread Pool FFI Import
# ----------------------

type
  NThreadMode {.size: 8.} = enum
    thrWorking
    thrSleep
    thrTerminate

{.passC: "-I" & includePath().}
{.compile: "pool.c".}
{.push header: "pool.h".}

type
  NThreadProc {.importc: "pool_fn_t".} =
    proc (data: pointer) {.nimcall, gcsafe.}
  NThreadTask {.importc: "pool_task_t".} = object
    fn: NThreadProc
    data: pointer
  NThreadLane {.importc: "pool_lane_t".} = object
    opaque: pointer
    rng: uint64
  # Thread Atomic Status Manager
  NThreadCounter {.importc: "pool_status_t".} = object
  NThreadStatus {.importc: "pool_status_t".} = object

{.push importc.}

proc pool_lane_init(lane: var NThreadLane, opaque: pointer)
proc pool_lane_destroy(lane: var NThreadLane)
proc pool_lane_push(lane: var NThreadLane, task: NThreadTask)
proc pool_lane_steal(lane: ptr NThreadLane): NThreadTask

proc pool_status_inc(counter: var NThreadCounter)
proc pool_status_dec(counter: var NThreadCounter)
proc pool_status_get(counter: var NThreadCounter): int64
proc pool_status_set(status: var NThreadStatus, mode: NThreadMode)
proc pool_status_get(status: var NThreadStatus): NThreadMode

{.pop.} # importc
{.pop.} # header

type
  NThreadGenericProc[T] = proc (data: ptr T) {.nimcall.}
  NThread = Thread[ptr NThreadLane]
  # Lock-free Thread Pool
  ThreadPool = object
    status {.align: 64.}: NThreadStatus
    works {.align: 64.}: NThreadCounter 
    awake {.align: 64.}: NThreadCounter
    # Thread Sleep
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
  pool_status_set(pool.status, thrWorking)
  # Wake Up All Threads
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
    var p: NThreadProc
    cast[ptr uint](unsafeAddr p)[] = 
      cast[uint](fn)
    push(pool, p, data)
  else: {.error: "attempted spawn proc with a gc'd type".}

proc sync*(pool: NThreadPool) =
  while pool_status_get(pool.works) > 0:
    cpuRelax() # Wait all Works Finalized

proc stop*(pool: NThreadPool) =
  pool_status_set(pool.status, thrSleep)

# --------------------------------
# Thread Pool Creation/Destruction
# --------------------------------

proc createThreadPool*(): NThreadPool =
  result = create(ThreadPool)
  pool_status_set(result.status, thrSleep)
  # Create Pool Sleep
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

proc working*(pool: NThreadPool): bool =
  pool_status_get(pool.works) > 0
