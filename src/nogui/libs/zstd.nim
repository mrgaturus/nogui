# zstd 1.5.x fundamental
# TODO: advanced api
{.passL: "-lzstd".}
{.push header: "<zstd.h>".}

type
  ZSTD_CCtx* {.importc.} = object
  ZSTD_DCtx* {.importc.} = object
  ZSTD_DStream* {.importc.} = object
  ZSTD_CStream* {.importc.} = object
  # ZSTD_compressStream2: input/output
  ZSTD_inBuffer* {.importc.} = object
    src*: pointer
    size*: int
    pos*: int
  ZSTD_outBuffer* {.importc.} = object
    dst*: pointer
    size*: int
    pos*: int
  # ZSTD_compressStream2: endOp
  ZSTD_EndDirective* {.importc, size: 4.} = enum
    ZSTD_e_continue = 0
    ZSTD_e_flush = 1
    ZSTD_e_end = 2

{.push importc.}

# ZSTD Version
proc ZSTD_versionNumber*(): uint
proc ZSTD_versionString*(): cstring

# ZSTD Simple API
proc ZSTD_compress*(
  dst: pointer, dstCapacity: int,
  src: pointer, srcSize: int,
  compressionLevel: int): int
proc ZSTD_decompress*(
  dst: pointer, dstCapacity: int,
  src: pointer, compressedSize: int): int
proc ZSTD_getFrameContentSize*(src: pointer, srcSize: int): uint64
proc ZSTD_findFrameCompressedSize*(src: pointer, srcSize: int): int
# ZSTD Helper Functions
proc ZSTD_compressBound*(srcSize: int): int
proc ZSTD_isError*(code: int): uint
proc ZSTD_getErrorName*(code: int): cstring
proc ZSTD_minCLevel*(): int32
proc ZSTD_maxCLevel*(): int32
proc ZSTD_defaultCLevel*(): int32

# ZSTD Explicit Context: Compress
proc ZSTD_createCCtx*(): ptr ZSTD_CCtx
proc ZSTD_freeCCtx*(cctx: ptr ZSTD_CCtx): int
proc ZSTD_compressCCtx*(
  cctx: ptr ZSTD_CCtx,
  dst: pointer, dstCapacity: int,
  src: pointer, srcSize: int,
  compressionLevel: int): int
# ZSTD Explicit Context: Decompress
proc ZSTD_createDCtx*(): ptr ZSTD_DCtx
proc ZSTD_freeDCtx*(dctx: ptr ZSTD_DCtx): int
proc ZSTD_decompressDCtx*(
  dctx: ptr ZSTD_DCtx,
  dst: pointer, dstCapacity: int,
  src: pointer, compressedSize: int): int

# ZSTD Streaming: Compress Prepare
proc ZSTD_createCStream*(): ptr ZSTD_CStream
proc ZSTD_freeCStream*(zcs: ptr ZSTD_CStream): int
proc ZSTD_initCStream*(zcs: ptr ZSTD_CStream, compressionLevel: int): int
proc ZSTD_CStreamInSize*(): int
proc ZSTD_CStreamOutSize*(): int
# ZSTD Streaming: Compress
proc ZSTD_compressStream2*(
  zcs: ptr ZSTD_CStream,
  output: ptr ZSTD_outBuffer,
  input: ptr ZSTD_inBuffer,
  endOp: ZSTD_EndDirective): int

# ZSTD Streaming: Decompress Prepare
proc ZSTD_createDStream*(): ptr ZSTD_DStream
proc ZSTD_freeDStream*(zds: ptr ZSTD_DStream): int
proc ZSTD_initDStream*(zds: ptr ZSTD_DStream): int
proc ZSTD_DStreamInSize*(): int
proc ZSTD_DStreamOutSize*(): int
# ZSTD Streaming: Decompress
proc ZSTD_decompressStream*(
  zds: ptr ZSTD_DStream,
  output: ptr ZSTD_outBuffer,
  input: ptr ZSTD_inBuffer): int

# ZSTD Memory Status - zstd 1.4
proc ZSTD_sizeof_CCtx*(cctx: ptr ZSTD_CCtx): int
proc ZSTD_sizeof_DCtx*(dctx: ptr ZSTD_DCtx): int
proc ZSTD_sizeof_CStream*(zcs: ptr ZSTD_CStream): int
proc ZSTD_sizeof_DStream*(zds: ptr ZSTD_DStream): int
# ZSTD Memory Status: Estimated Size
proc ZSTD_estimateCCtxSize*(compressionLevel: int): int
proc ZSTD_estimateDCtxSize*(): int
proc ZSTD_estimateCStreamSize*(compressionLevel: int): int
proc ZSTD_estimateDStreamSize*(windowSize: int): int

{.pop.} # importc
{.pop.} # header
