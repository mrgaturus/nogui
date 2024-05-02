import ../native/ffi
import callback

# -------------------------
# Main Loop + Frame Limiter
# -------------------------

template loop*(ms: int, body: untyped) =
  let limit = nogui_time_ms(ms)
  var a, b: GUINativeTime
  # Procedure Duration
  while true:
    a = nogui_time_now()
    body # Execute Body
    b = nogui_time_now()
    # Calculate Sleep Time
    nogui_time_sleep(limit - b + a)

# ---------------------
# Callback Timer Object
# ---------------------

type
  Timer = object
    next: ptr Timer
    # Callback Caller
    stamp: GUINativeTime
    cb: GUICallback
  TimerCallback = ptr Timer
  # Timer Queues
  GUITimers* = object
    list: TimerCallback

# Global Timer Queue
var queue: GUITimers
proc useTimers*(): ptr GUITimers =
  addr queue

# -------------------
# Callback Timer Poll
# -------------------

proc nogui_timers_pump*(timers: ptr GUITimers) =
  var
    prev: TimerCallback
    timer = timers.list
  # Check Dispatched Timers
  let now = nogui_time_now()
  while not isNil(timer):
    # Check if time surpassed
    if now > timer.stamp:
      # Remove Timer From List
      if timer == timers.list:
        timers.list = timer.next
      else: prev.next = timer.next
      # Consume Timer
      send(timer.cb)
      dealloc(timer)
    # Next Timer Check
    prev = timer
    timer = timer.next

proc `=destroy`(timers: GUITimers) =
  var
    prev: TimerCallback
    timer = timers.list
  # Dealloc Timers
  while not isNil(timer):
    prev = timer
    timer = timer.next
    # Dealloc Timer
    dealloc(prev)

# ----------------------
# Callback Timer Creator
# ----------------------

proc timeout*(cb: GUICallback, ms: int32) =
  let
    timers = addr queue
    stamp = nogui_time_now() + nogui_time_ms(ms)
  # Find if Callback was not Queued
  var timer = timers.list
  while not isNil(timer):
    # Avoid Adding Again
    if timer.cb == cb:
      return
    timer = timer.next
  # Create new Timer
  timer = create(Timer)
  timer.stamp = stamp
  timer.cb = cb
  # Add Timer to Queue
  timer.next = timers.list
  timers.list = timer

proc timestop*(cb: GUICallback) =
  let timers = addr queue
  # Find if Callback was Queued
  var
    timer = timers.list
    prev: TimerCallback
  while not isNil(timer):
    # Avoid Adding Again
    if timer.cb == cb:
      break
    prev = timer
    timer = timer.next
  # Check if Timer Found
  if isNil(timer):
    return
  # Remove Timer from Queue
  if timer == timers.list:
    timers.list = timer.next
  else: prev.next = timer.next
  # Dealloc Timer
  dealloc(timer)
