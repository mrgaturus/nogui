import nogui/async/coro

type
  Walker = object
    name: cstring
    i, len, sleep: int
    # Finalized Callback
    cb: CoroCallback

proc sleep0task(coro: Coroutine[Walker]) =
  let data = coro.data
  # Walk Coroutine Data
  if data.i < data.len:
    inc(data.i)
    # Pass Continuation
    echo "coroutine ", data.name, ": ", data.i
    coro.pass(sleep0task)
    return
  # Send Finalized Callback
  coro.send(data.cb)

# ----------------------
# Coroutine Main Testing
# ----------------------

proc finalize0cb(data: ptr Walker) =
  echo "finalized ", data.name, ": ", data.i

proc walker(name: cstring, len, sleep: int): Coroutine[Walker] =
  result = coroutine(Walker)
  result.pass(sleep0task)
  # Walker Step Size
  let data = result.data
  data.len = len
  data.sleep = sleep
  data.name = name
  # Define Callback
  data.cb.fn = cast[CoroCallbackProc](finalize0cb)
  data.cb.data = data

proc main() =
  let
    man = createCoroutineManager()
    coro0 = walker("one", 10, 16)
    coro1 = walker("other", 5, 256)
    coro2 = walker("another", 25, 16)
  # Spawn Coroutine and Wait
  man.spawn(coro0)
  man.spawn(coro1)
  man.spawn(coro2)
  coro0.wait()
  coro1.wait()
  coro2.wait()
  #echo "coroutine finalized: ", coro0.data.i
  # Destroy Coroutine Manager
  for cb in man.pump():
    cb.fn(cb.data)
  man.destroy()

when isMainModule:
  main()
