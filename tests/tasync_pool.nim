import nogui/async/pool
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
  for i in 0 ..< 1000:
    for rngs in mitems(rngs0single):
      xor0task(addr rngs)
  echo "done single threading"
  # Dispatch Multi Threading
  for i in 0 ..< 1000:
    pool.start()
    for rngs in mitems(rngs0multi):
      pool.spawn(xor0task, addr rngs)
    pool.sync()
    pool.stop()
  echo "done multi threading"
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
    sleep(1000)
    pool.cancel()
  echo "done multi-threading cancel 0"
  # Backup Cancelation Data
  rngs0single = rngs0multi
  # Try Again
  block cancel1:
    pool.start()
    sleep(1000)
    pool.sync()
    pool.stop()
  echo "done multi-threading cancel 1"
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
