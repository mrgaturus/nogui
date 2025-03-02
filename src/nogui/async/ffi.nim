# Avoid import os.parentDir
# TODO: use nimony $path
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
  NThreadMode* {.size: 8.} = enum
    thrWorking
    thrSleep
    thrTerminate

{.compile: "pool.c".}
{.compile: "green.S".}
{.push header: includePath() & "async.h".}

type
  NThreadProc* {.importc: "pool_fn_t".} =
    proc (data: pointer) {.nimcall, gcsafe.}
  NThreadTask* {.importc: "pool_task_t".} = object
    data*: pointer
    fn*: NThreadProc
  NThreadLane* {.importc: "pool_lane_t".} = object
    opaque*: pointer
    rng*: uint64
  # Thread Atomic Status
  NThreadCounter* {.importc: "pool_status_t".} = object
  NThreadStatus* {.importc: "pool_status_t".} = object
  NGreenStack* {.importc: "green_vmstack_t".} = object
  NGreenState* {.importc: "green_vmstate_t".} = object
  NGreenProc* {.importc: "green_vmproc_t".} =
    proc (data: pointer) {.nimcall, gcsafe.}

{.push importc.}

proc green_callctx*(fn: NGreenProc, data, stack: pointer)
proc green_jumpctx*(state: ptr NGreenState, signal: int32)
proc green_setctx*(state: ptr NGreenState): int32

proc pool_lane_init*(lane: var NThreadLane, opaque: pointer)
proc pool_lane_reset*(lane: var NThreadLane)
proc pool_lane_destroy*(lane: var NThreadLane)
proc pool_lane_push*(lane: var NThreadLane, task: NThreadTask)
proc pool_lane_steal*(lane: ptr NThreadLane): NThreadTask

proc pool_status_inc*(counter: var NThreadCounter)
proc pool_status_dec*(counter: var NThreadCounter)
proc pool_status_reset*(counter: var NThreadCounter)
proc pool_status_get*(counter: var NThreadCounter): int64
proc pool_status_set*(status: var NThreadStatus, mode: NThreadMode)
proc pool_status_get*(status: var NThreadStatus): NThreadMode

{.pop.} # importc
{.pop.} # header
