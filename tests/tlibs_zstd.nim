import nogui/libs/zstd

type
  ZSTDStep = object
    srcSeek: int
    srcBytes: int
    dstBytes: int
  ZSTDBytes = ptr UncheckedArray[byte]
  ZSTDSteps = ptr UncheckedArray[ZSTDStep]
  ZSTDBuffers = object
    filename: string
    # ZSTD Buffers
    srcBuffer: pointer
    dstBuffer: pointer
    srcBytes: int
    dstBytes: int
    # ZSTD Custom Streaming
    stepBuffer: pointer
    stepLen: int

# ------------------
# ZSTD Error Killing
# ------------------

proc dieZSTD(msg: cstring) =
  stderr.write(msg)
  stderr.write('\n')
  quit(not 0)

proc checkZSTD(code: int) =
  if ZSTD_isError(code) > 0:
    dieZSTD ZSTD_getErrorName(code)

# -----------------
# ZSTD File Loading
# -----------------

proc readZSTD(filename: string): ptr ZSTDBuffers =
  var file: File
  result = create(ZSTDBuffers)
  if not open(file, filename, fmRead):
    dieZSTD("failed opening file")
  # Allocate Buffers
  let
    bytes = getFileSize(file)
    buffer0 = alloc(bytes)
    buffer1 = alloc(bytes * 2)
    buffer2 = alloc(bytes)
  # Read All File Contents
  if readBuffer(file, buffer0, bytes) != bytes:
    dieZSTD("failed reading file")
  # Store Buffers
  result.filename = filename
  result.srcBuffer = buffer0
  result.dstBuffer = buffer1
  result.stepBuffer = buffer2
  result.srcBytes = bytes
  # Close File
  file.close()

proc compare(man: ptr ZSTDBuffers) =
  var file: File
  if not open(file, man.filename, fmRead):
    dieZSTD("failed opening file")
  # Compare Buffers
  const chunkSize = 1 shl 17
  let chunk = alloc(chunkSize)
  let buffer0 = cast[ZSTDBytes](man.srcBuffer)
  var bytes, cursor: int
  while true:
    bytes = readBuffer(file, chunk, chunkSize)
    if bytes <= 0: break
    # Check Buffer Bytes
    if cmpMem(addr buffer0[cursor], chunk, bytes) != 0:
      dieZSTD("mismatch comparing decompress")
    cursor += bytes
  # Compare Readed Bytes
  if cursor != man.srcBytes:
    dieZSTD("mismatch comparing decompress")
  # Close File
  dealloc(chunk)
  file.close()

proc report(man: ptr ZSTDBuffers) =
  echo "src size: ", man.srcBytes, " dst size: ", man.dstBytes

proc close(man: ptr ZSTDBuffers) =
  dealloc(man.srcBuffer)
  dealloc(man.dstBuffer)
  dealloc(man.stepBuffer)

# -----------------------
# ZSTD Simple Compression
# -----------------------

proc compressSimple(man: ptr ZSTDBuffers) =
  man.dstBytes = ZSTD_compress(
    man.dstBuffer, man.srcBytes,
    man.srcBuffer, man.srcBytes, 4)
  # Check ZSTD Errors
  checkZSTD(man.dstBytes)
  # Decompress and Compare
  man.srcBytes = ZSTD_decompress(
    man.srcBuffer, man.srcBytes,
    man.dstBuffer, man.dstBytes)
  # Check And Compare
  checkZSTD(man.srcBytes)
  man.compare()
  man.report()

proc compressExplicit(man: ptr ZSTDBuffers) =
  let
    cctx = ZSTD_createCCtx()
    dctx = ZSTD_createDCtx()
  # Decompress Using Context
  man.dstBytes = ZSTD_compressCCtx(cctx,
    man.dstBuffer, man.srcBytes,
    man.srcBuffer, man.srcBytes, 4)
  # Check ZSTD Errors
  checkZSTD(man.dstBytes)
  # Decompress and Compare
  man.srcBytes = ZSTD_decompressDCtx(dctx,
    man.srcBuffer, man.srcBytes,
    man.dstBuffer, man.dstBytes)
  # Check And Compare
  checkZSTD(man.srcBytes)
  # Show Memory Usage: Compress Explicit
  echo "explicit ram compress: ", ZSTD_sizeof_CCtx(cctx)
  echo "explicit ram decompress: ", ZSTD_sizeof_DCtx(dctx)
  man.compare()
  man.report()
  # Destroy Context
  discard ZSTD_freeCCtx(cctx)
  discard ZSTD_freeDCtx(dctx)

# ---------------------
# ZSTD Streaming Blocks
# ---------------------

proc stepPointer(buffer: var ZSTD_inBuffer, bytes: int) =
  let p = cast[ZSTDBytes](buffer.src)
  buffer.src = addr p[buffer.pos]
  buffer.size = bytes
  buffer.pos = 0

proc stepPointer(buffer: var ZSTD_outBuffer, bytes: int) =
  let p = cast[ZSTDBytes](buffer.dst)
  buffer.dst = addr p[buffer.pos]
  buffer.size = bytes
  buffer.pos = 0

# ----------------------------------
# ZSTD Streaming Compression: Simple
# ----------------------------------

proc streamCompress(man: ptr ZSTDBuffers) =
  let zcs = ZSTD_createCStream()
  discard ZSTD_initCStream(zcs, 4)
  # Prepare Buffer Accessors
  let inSize = ZSTD_CStreamInSize()
  var src = ZSTD_inBuffer(src: man.srcBuffer)
  var dst = ZSTD_outBuffer(dst: man.dstBuffer)
  # Streaming Compress Blocks
  var size: int
  var rem = man.srcBytes
  var mode = ZSTD_e_continue
  while rem > 0:
    let bytes = min(rem, inSize)
    dst.stepPointer(man.dstBytes)
    src.stepPointer(bytes)
    # Check if is Last Block
    if rem <= inSize:
      mode = ZSTD_e_end
    # Stream Compressed
    while true:
      let r = ZSTD_compressStream2(zcs, addr dst, addr src, mode)
      # Step Buffer
      checkZSTD(r)
      if mode == ZSTD_e_end:
        if r == 0: break
      elif src.pos == src.size:
        break
    # Step Bytes
    rem -= bytes
    size += dst.pos
  # Change Current Size
  man.dstBytes = size
  # Delete ZSTD Stream
  echo "stream ram compress: ", ZSTD_sizeof_CStream(zcs)
  discard ZSTD_freeCStream(zcs)

proc streamDecompress(man: ptr ZSTDBuffers) =
  let zds = ZSTD_createDStream()
  discard ZSTD_initDStream(zds)
  # Prepare Buffer Accessors
  let outSize = ZSTD_DStreamInSize()
  var src = ZSTD_inBuffer(src: man.dstBuffer)
  var dst = ZSTD_outBuffer(dst: man.srcBuffer)
  # Streaming Compress Blocks
  var size: int
  var rem = man.dstBytes
  while rem > 0:
    let bytes = min(rem, outSize)
    dst.stepPointer(man.srcBytes)
    src.stepPointer(bytes)
    # Stream Compressed
    while true:
      let r = ZSTD_decompressStream(zds, addr dst, addr src)
      # Step Buffer
      checkZSTD(r)
      size += dst.pos
      if src.pos == src.size:
        break
    # Step Bytes
    rem -= bytes
  # Change Current Size
  man.srcBytes = size
  # Delete ZSTD Stream
  echo "stream ram decompress: ", ZSTD_sizeof_DStream(zds)
  discard ZSTD_freeDStream(zds)

proc streamSimple(man: ptr ZSTDBuffers) =
  man.streamCompress()
  man.streamDecompress()
  # Compare and Report
  man.compare()
  man.report()

# ----------------------------------
# ZSTD Streaming Compression: Custom
# ----------------------------------

proc streamCustomCompress(man: ptr ZSTDBuffers) =
  let zcs = ZSTD_createCStream()
  discard ZSTD_initCStream(zcs, 4)
  # Prepare Buffer Managers
  const inStepSize = 8192
  var steps = cast[ZSTDSteps](man.stepBuffer)
  var src = ZSTD_inBuffer(src: man.srcBuffer)
  var dst = ZSTD_outBuffer(dst: man.dstBuffer)
  # Streaming Compress Blocks
  var size, idx: int
  var rem = man.srcBytes
  var mode = ZSTD_e_flush
  while rem > 0:
    let bytes = min(rem, inStepSize)
    dst.stepPointer(man.dstBytes)
    src.stepPointer(bytes)
    # Check if is Last Block
    if rem <= inStepSize:
      mode = ZSTD_e_end
    # Configure Current Step
    let step = addr steps[idx]
    step.srcSeek = size
    # Stream Compressed
    while true:
      let r = ZSTD_compressStream2(zcs, addr dst, addr src, mode)
      # Step Buffer
      checkZSTD(r)
      if mode == ZSTD_e_end:
        if r == 0: break
      elif src.pos == src.size:
        break
    # Step Bytes
    inc(idx)
    rem -= bytes
    size += dst.pos
    step.srcBytes = dst.pos
    step.dstBytes = src.size
  # Change Current Size
  man.dstBytes = size
  man.stepLen = idx
  # Delete ZSTD Stream
  echo "custom ram compress: ", ZSTD_sizeof_CStream(zcs)
  discard ZSTD_freeCStream(zcs)

proc streamCustomDecompress(man: ptr ZSTDBuffers) =
  let zds = ZSTD_createDStream()
  discard ZSTD_initDStream(zds)
  # Prepare Buffer Managers
  var steps = cast[ZSTDSteps](man.stepBuffer)
  var dst = ZSTD_outBuffer(dst: man.srcBuffer)
  # Decompress Each Step
  var size: int
  let l = man.stepLen
  for i in 0 ..< l:
    let step = addr steps[i]
    var src = ZSTD_inBuffer(src: man.dstBuffer, pos: step.srcSeek)
    src.stepPointer(step.srcBytes)
    dst.stepPointer(man.srcBytes)
    # Stream Decompress
    while true:
      let r = ZSTD_decompressStream(zds, addr dst, addr src)
      # Step Buffer
      checkZSTD(r)
      size += dst.pos
      if src.pos == src.size:
        break
  # Change Current Sizes
  man.srcBytes = size
  # Delete ZSTD Stream
  echo "custom ram decompress: ", ZSTD_sizeof_DStream(zds)
  discard ZSTD_freeDStream(zds)

proc streamCustom(man: ptr ZSTDBuffers) =
  man.streamCustomCompress()
  man.streamCustomDecompress()
  # Compare and Report
  man.compare()
  man.report()

# -----------------
# ZSTD Main Program
# -----------------

proc main() =
  let man = readZSTD("pack/libs/test.data")
  # Simple Compression
  man.compressSimple()
  man.compressExplicit()
  man.streamSimple()
  man.streamCustom()
  # Terminate Manager
  man.close()

when isMainModule:
  main()
