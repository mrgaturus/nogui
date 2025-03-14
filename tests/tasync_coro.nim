import nogui/async/coro

type
  Test = object
    label: cstring
    pause: bool
    a, b: int
    # Finalized Callback
    cb: CoroCallback

proc test0cb(test: ptr Test) =
  echo "finalized: ", test[]

proc test0handle(coro: Coroutine[Test], signal: CoroSignal) =
  echo "[signal] ", coro.data.label, ": ", signal

proc test0task(coro: Coroutine[Test]) =
  let test = coro.data
  coro.lock():
    for i in test.a .. test.b:
      echo test.label, ": ", i
      coro.pass()
  # Cancelation
  coro.send(test.cb)
  if test.pause:
    coro.pause()
    assert false

# -------------------------
# Coroutine Testing: Object
# -------------------------

proc createTest(label: cstring, a, b: int, pause = false): Coroutine[Test] =
  result = coroutine(Test)
  result.setProc(test0task)
  result.setHandle(test0handle)
  # Define Testing
  let test = result.data
  test.label = label
  test.pause = pause
  test.a = a
  test.b = b
  # Define Callback
  test.cb.fn = cast[CoroCallbackProc](test0cb)
  test.cb.data = test

proc main() =
  let
    coros = createCoroutineManager()
    coro0 = createTest("coroutine 0", 0, 5, pause = true)
    coro1 = createTest("coroutine 1", 0, 10)
    coro2 = createTest("coroutine 2", 0, 15)
  # Spawn Coroutines
  coros.spawn(coro0)
  coros.spawn(coro1)
  coros.spawn(coro2)
  coro0.wait()
  coro1.wait()
  coro2.wait()
  # Destroy Coroutine Manager
  for cb in coros.pump():
    cb.fn(cb.data)
  echo "-- finalized coroutines --"
  discard stdin.readLine()
  coros.destroy()

when isMainModule:
  main()
