import nogui/async/pool
from times import cpuTime
from os import sleep

type
  XORShift = object
    n: uint64

proc next(rng: ptr XORShift) =
  var idx = rng.n
  # Calculate xorshift Random Number
  idx = idx xor idx shl 13
  idx = idx xor idx shr 7
  idx = idx xor idx shl 17
  # Return Next Random
  rng.n = idx

proc xor0task(data: ptr XORShift) =
  for i in 0 ..< 10:
    data.next()

proc fuse0task(data: ptr XORShift) =
  data.n = 0
  sleep(16)

# ------------------
# Main Parallel Test
# ------------------

proc main() =
  const magic = uint64(0xABCDEF_ABCDEF)
  const size = uint64(1000)
  let pool = createThreadPool()
  # Thread Pool Data
  var rngs0single: seq[XORShift]
  var rngs0multi: seq[XORShift]
  rngs0single.setLen(size)
  rngs0multi.setLen(size)
  for i in 0 ..< size:
    rngs0single[i].n = magic + i
    rngs0multi[i].n = magic + i

  # Dispatch Single Threading
  let t0 = cpuTime()
  for i in 0 ..< 1000:
    for rngs in mitems(rngs0single):
      xor0task(addr rngs)
  let t1 = cpuTime()
  echo "done single threading ", (t1 - t0)
  # Dispatch Multi Threading
  for i in 0 ..< 1000:
    pool.start()
    for rngs in mitems(rngs0multi):
      pool.spawn(xor0task, addr rngs)
    pool.sync()
    pool.stop()
  let t2 = cpuTime()
  echo "done multi  threading ", (t2 - t1)
  # Compare Values Equality
  var failed: bool
  for i in 0 ..< size:
    if rngs0single[i].n != rngs0multi[i].n:
      echo "failed data check at: ", i
      failed = true

  # Dispatch Multi Threading Cancel
  block cancel0:
    pool.start()
    for rngs in mitems(rngs0multi):
      pool.spawn(fuse0task, addr rngs)
    # Cancel Pool Operation
    sleep(16)
    pool.cancel()
    pool.stop()
  echo "done multi  threading cancel 0"
  # Dispatch Multi Threading Cancel
  block cancel1:
    pool.start()
    # Cancel Pool Operation: Pass 1
    for rngs in mitems(rngs0multi):
      pool.spawn(fuse0task, addr rngs)
    sleep(16)
    pool.cancel()
    # Cancel Pool Operation: Pass 2
    for rngs in mitems(rngs0multi):
      pool.spawn(fuse0task, addr rngs)
    sleep(16)
    pool.cancel()
    pool.stop()
  echo "done multi  threading cancel 1"
  # Backup Cancelation Data
  rngs0single = rngs0multi
  block cancel2:
    pool.start()
    pool.sync()
    pool.stop()
  echo "done multi  threading cancel 2"
  # Compare Values Equality
  var fuse: bool
  for i in 0 ..< size:
    if rngs0single[i].n != rngs0multi[i].n:
      echo "failed data check at: ", i
      fuse = true

  # Finalize Thread Pool
  assert failed == false
  assert fuse == false
  pool.destroy()

when isMainModule:
  main()
