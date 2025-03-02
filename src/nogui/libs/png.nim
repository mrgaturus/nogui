# small subset of libpng 1.6
# rgba modern usages
{.passL: "-lpng16".}
{.push header: "<png.h>".}

type
  PNGstruct* {.importc: "png_struct".} = object
  PNGinfo* {.importc: "png_info".} = object
  # PNG Function Pointers Callbacks
  PNGerror* {.importc: "png_error_ptr".} =
    proc (png: ptr PNGstruct, msg: cstring) {.nimcall.}
  PNGrw* {.importc: "png_rw_ptr".} =
    proc (png: ptr PNGstruct, data: pointer, size: csize_t) {.nimcall.}
  PNGflush* {.importc: "png_flush_ptr".} =
    proc (png: ptr PNGstruct) {.nimcall.}
  PNGstatus* {.importc: "png_read_status_ptr".} =
    proc (png: ptr PNGstruct, row: uint32, pass: int32) {.nimcall.}
  # PNG Integer may differ from original representation
  PNGbyte* {.importc: "png_byte".} = uint8
  PNGint16* {.importc: "png_int_16".} = int16
  PNGint32* {.importc: "png_int_32".} = int32
  PNGuint16* {.importc: "png_uint_16".} = uint16
  PNGuint32* {.importc: "png_uint_32".} = uint32
  # PNG Color Bits Per Channel [bpc]
  PNGcolor8* {.importc: "png_color_8".} = object
    red, green, blue: PNGbyte
    gray, alpha: PNGbyte

const
  PNG_COLOR_MASK_NOTHING: PNGint32 = 0
  PNG_COLOR_MASK_PALETTE: PNGint32 = 1
  PNG_COLOR_MASK_COLOR: PNGint32 = 2
  PNG_COLOR_MASK_ALPHA: PNGint32 = 4
  # color type: Note that not all combinations are legal
  PNG_COLOR_TYPE_GRAY* = PNG_COLOR_MASK_NOTHING
  PNG_COLOR_TYPE_PALETTE* = PNG_COLOR_MASK_COLOR or PNG_COLOR_MASK_PALETTE
  PNG_COLOR_TYPE_RGB* = PNG_COLOR_MASK_COLOR
  PNG_COLOR_TYPE_RGB_ALPHA* = PNG_COLOR_MASK_COLOR or PNG_COLOR_MASK_ALPHA
  PNG_COLOR_TYPE_GRAY_ALPHA*  = PNG_COLOR_MASK_ALPHA
  # interlace type: These values should NOT be changed
  PNG_INTERLACE_NONE*: PNGint32 = 0
  PNG_INTERLACE_ADAM7*: PNGint32 = 1
  PNG_INTERLACE_LAST*: PNGint32 = 2
  # filter type: From Legacy PNG 1.0-1.2
  PNG_FILTER_TYPE_BASE*: PNGint32 = 0
  PNG_FILTER_TYPE_DEFAULT*: PNGint32 = 0
  # compression type: From Legacy PNG 1.0-1.2
  PNG_COMPRESSION_TYPE_BASE*: PNGint32 = 0
  PNG_COMPRESSION_TYPE_DEFAULT*: PNGint32 = 0

const
  # png_set_filler: flags
  PNG_FILLER_BEFORE*: PNGint32 = 0
  PNG_FILLER_AFTER*: PNGint32 = 1
  # png_get_valid: flag
  PNG_INFO_gAMA* = 0x0001u32
  PNG_INFO_sBIT* = 0x0002u32
  PNG_INFO_cHRM* = 0x0004u32
  PNG_INFO_PLTE* = 0x0008u32
  PNG_INFO_tRNS* = 0x0010u32
  PNG_INFO_bKGD* = 0x0020u32
  PNG_INFO_hIST* = 0x0040u32
  PNG_INFO_pHYs* = 0x0080u32
  PNG_INFO_oFFs* = 0x0100u32
  PNG_INFO_tIME* = 0x0200u32
  PNG_INFO_pCAL* = 0x0400u32
  # png_set_compression_level: default
  PNG_ZLIB_DEFAULT*: PNGint32 = -1

{.push importc.}

let PNG_LIBPNG_VER_STRING*: cstring
proc png_sig_cmp*(sig: pointer, start, count: csize_t): int32
proc png_set_sig_bytes*(png: ptr PNGstruct, num: int32)
proc png_error*(png: ptr PNGstruct, msg: cstring)
proc png_warning*(png: ptr PNGstruct, msg: cstring)
# PNG Structure Creation/Destruction
proc png_create_info_struct*(png: ptr PNGstruct): ptr PNGinfo
proc png_create_read_struct*(version: cstring, errorData: pointer, errorProc, warningProc: PNGerror): ptr PNGstruct
proc png_create_write_struct*(version: cstring, errorData: pointer, errorProc, warningProc: PNGerror): ptr PNGstruct
proc png_destroy_read_struct*(png: ptr ptr PNGstruct, info, infoEnd: ptr ptr PNGinfo)
proc png_destroy_write_struct*(png: ptr ptr PNGstruct, info: ptr ptr PNGinfo)
# PNG Structure Read/Write Callback
proc png_set_read_fn*(png: ptr PNGstruct, io: pointer, fn: PNGrw)
proc png_set_write_fn*(png: ptr PNGstruct, io: pointer, fn: PNGrw, flush: PNGflush)
proc png_set_read_status_fn*(png: ptr PNGstruct, fn: PNGstatus)
proc png_set_write_status_fn*(png: ptr PNGstruct, fn: PNGstatus)
proc png_get_io_ptr*(png: ptr PNGstruct): pointer
proc png_get_error_ptr*(png: ptr PNGstruct): pointer

# PNG Structure Transformations to RGBA
proc png_set_expand*(png: ptr PNGstruct)
proc png_set_strip_16*(png: ptr PNGstruct)
proc png_set_gray_to_rgb*(png: ptr PNGstruct)
proc png_set_interlace_handling*(png: ptr PNGstruct)
proc png_set_filler*(png: ptr PNGstruct, filler: PNGuint32, flags: PNGint32)

# PNG Structure Read Header
proc png_read_info*(png: ptr PNGstruct, info: ptr PNGinfo)
proc png_read_update_info*(png: ptr PNGstruct, info: ptr PNGinfo)
proc png_get_bit_depth*(png: ptr PNGstruct, info: ptr PNGinfo): PNGint32
proc png_get_channels*(png: ptr PNGstruct, info: ptr PNGinfo): PNGint32
proc png_get_valid*(png: ptr PNGstruct, info: ptr PNGinfo, flag: PNGuint32): PNGuint32
proc png_get_IHDR*(png: ptr PNGstruct, info: ptr PNGinfo,
  width, height: ptr PNGuint32,
  bit_depth, color_type: ptr PNGint32,
  interlace, compression, filter: ptr PNGint32): PNGuint32
proc png_get_iCCP*(png: ptr PNGstruct, info: ptr PNGinfo,
  name: ptr cstring, compression: ptr PNGint32,
  data: ptr pointer, dataSize: ptr PNGuint32)
# PNG Structure Read Image Buffer
proc png_read_image*(png: ptr PNGstruct, rows: ptr pointer)
proc png_read_end*(png: ptr PNGstruct, info: ptr PNGinfo)

# PNG Structure Write Header
proc png_write_info*(png: ptr PNGstruct, info: ptr PNGinfo)
proc png_set_compression_level*(png: ptr PNGstruct, level: PNGint32)
proc png_set_sBIT*(png: ptr PNGstruct, info: ptr PNGinfo, sbit: ptr PNGcolor8)
proc png_set_packing*(png: ptr PNGstruct)
proc png_set_IHDR*(png: ptr PNGstruct, info: ptr PNGinfo,
  width, height: PNGuint32,
  bit_depth, color_type: PNGint32,
  interlace, compression, filter: PNGint32)
proc png_set_iCCP*(png: ptr PNGstruct, info: ptr PNGinfo,
  name: cstring, compression: PNGint32,
  data: pointer, dataSize: PNGuint32)
# PNG Structure Write Image Buffer
proc png_write_image*(png: ptr PNGstruct, rows: ptr pointer)
proc png_write_end*(png: ptr PNGstruct, info: ptr PNGinfo)

{.pop.} # importc
{.pop.} # header

{.emit: "#define png_error_setjmp(png) setjmp(png_jmpbuf(png))".}
{.emit: "#define png_error_longjmp(png) longjmp(png_jmpbuf(png), 1)".}
proc png_error_setjmp(png: ptr PNGstruct): int32 {.importc, nodecl.}
proc png_error_longjmp*(png: ptr PNGstruct) {.importc, nodecl.}

template png_error_setjmp*(png: ptr PNGstruct, body: untyped) =
  let frame = getFrameState()
  if png_error_setjmp(png) != 0:
    setFrameState(frame)
    body

# ----------------------------
# libpng Nim RGBA Simple Usage
# TODO: iCC profile manager
# ----------------------------

type
  PNGprocMessage* = proc(data: pointer, msg: cstring) {.nimcall.}
  PNGprocStatus* = proc(data: pointer, rows, i: int32) {.nimcall.}
  PNGreport* = object
    warn*, error*: PNGprocMessage
    status*: PNGprocStatus
    data*: pointer
  # PNG Nim RGBA Handle
  PNGhandle = object
    seek, size: int
    raw: pointer
    file: File
    # PNG Structures
    png: ptr PNGStruct
    info: ptr PNGinfo
    report*: PNGreport
    # Image Header
    w*, h*, bytes*: PNGint32
    level*: PNGint32
    adam7*, useless: bool
    # Image RGBA Buffer
    buffer*: ptr UncheckedArray[PNGbyte]
    rows: ptr UncheckedArray[pointer]
  # PNG Nim RGBA Read/Write
  PNGhandleRead {.borrow.} = distinct PNGhandle
  PNGhandleWrite {.borrow.} = distinct PNGhandle
  PNGnimRead* = ptr PNGhandleRead
  PNGnimWrite* = ptr PNGhandleWrite

proc destroy(p: ptr PNGhandle) =
  p.w = 0
  p.h = 0
  p.level = 0
  p.adam7 = false
  # Dealloc Buffers
  if not isNil(p.rows):
    dealloc(p.rows)
    p.rows = nil
  if not isNil(p.buffer):
    dealloc(p.buffer)
    p.buffer = nil
  # Release File
  close(p.file)

# ---------------------------
# libpng Nim Status Callbacks
# ---------------------------

proc cbError(png: ptr PNGstruct, msg: cstring) =
  let p = cast[ptr PNGreport](png_get_error_ptr png)
  # Call Error Callback
  if not isNil(p.error):
    p.error(p.data, msg)
  else:
    stderr.write(msg)
    stderr.write('\n')
  # Abort libpng Operation
  png_error_longjmp(png)

proc cbWarning(png: ptr PNGstruct, msg: cstring) =
  let p = cast[ptr PNGreport](png_get_error_ptr png)
  # Call Warning Callback
  if not isNil(p.warn):
    p.warn(p.data, msg)
  else:
    stderr.write(msg)
    stderr.write('\n')

proc cbStatus(png: ptr PNGstruct, row: uint32, pass: int32) =
  let p = cast[ptr PNGhandle](png_get_io_ptr png)
  let r = addr p.report
  # Call Status Callback
  if not isNil(r.status):
    r.status(r.data, p.h, int32 row)

# ------------------------
# libpng Nim I/O Callbacks
# ------------------------

proc cbReadBuffer(png: ptr PNGstruct, data: pointer, size: csize_t) =
  let
    p = cast[ptr PNGhandle](png_get_io_ptr png)
    raw = cast[int](p.raw) + p.seek
  # Read Buffer to libpng
  p.seek += int(size)
  if p.seek <= p.size:
    copyMem(data, cast[pointer](raw), size)
    return
  # Abort when Buffer Overflow
  png_error(png, "buffer overflow")

proc cbReadFile(png: ptr PNGstruct, data: pointer, size: csize_t) =
  let p = cast[ptr PNGhandle](png_get_io_ptr png)
  # Read Bytes from file to libpng
  if readBuffer(p.file, data, size) != cast[int](size):
    png_error(png, "failed reading file bytes")

proc cbWriteFile(png: ptr PNGstruct, data: pointer, size: csize_t) =
  let p = cast[ptr PNGhandle](png_get_io_ptr png)
  # Write Bytes from libpng to file
  if writeBuffer(p.file, data, size) != cast[int](size):
    png_error(png, "failed writing file bytes")

proc cbWriteFlush(png: ptr PNGstruct) =
  let p = cast[ptr PNGhandle](png_get_io_ptr png)
  # Flush File Operations
  flushFile(p.file)

# ----------------------
# libpng Nim RGBA Reader
# ----------------------

proc checkSignature(p: PNGnimRead): bool =
  var aux: array[8, uint8]
  var sig = p.raw
  # Read File Signature
  if isNil(sig):
    sig = cast[pointer](addr aux)
    if p.seek > 0: p.seek = readBuffer(p.file, sig, 8)
  # Check and Skip PNG Buffer Bytes
  result = png_sig_cmp(sig, 0, 8) == 0
  png_set_sig_bytes(p.png, 8)
  p.seek = 8

proc prepareReadPNG(p: PNGnimRead) =
  if not p.checkSignature():
    png_error(p.png, "invalid png file")
  png_read_info(p.png, p.info)
  # IHDR Basic Information
  var
    width, height: PNGuint32
    bit_depth, color_type: PNGint32
    interlace, compression, filter: PNGint32
  # Check Bit Depth Properly
  bit_depth = png_get_bit_depth(p.png, p.info)
  if bit_depth < 1 or bit_depth > 16:
    png_error(p.png, "invalid bits per channel")
  # Read IHDR First Pass
  discard png_get_IHDR(p.png, p.info,
    addr width, addr height,
    addr bit_depth,
    addr color_type,
    addr interlace,
    addr compression,
    addr filter);
  # Transform to 8-bit - gdk-pixbuf/io-png.c
  if color_type == PNG_COLOR_TYPE_PALETTE and bit_depth <= 8:
    png_set_expand(p.png)
  elif color_type == PNG_COLOR_TYPE_GRAY and bit_depth < 8:
    png_set_expand(p.png)
  elif png_get_valid(p.png, p.info, PNG_INFO_tRNS) != 0:
    png_set_expand(p.png)
  elif bit_depth < 8:
    png_set_expand(p.png)
  if bit_depth == 16:
    png_set_strip_16(p.png)
  # Transform to RGBA
  if color_type == PNG_COLOR_TYPE_GRAY or 
      color_type == PNG_COLOR_TYPE_GRAY_ALPHA:
    png_set_gray_to_rgb(p.png)
  if color_type != PNG_COLOR_TYPE_RGB_ALPHA:
    png_set_filler(p.png, 0xFFFF, PNG_FILLER_AFTER)
  # Handle ADAM7 Interlace
  if interlace != PNG_INTERLACE_NONE:
    png_set_interlace_handling(p.png)
  # Read IHDR Second Pass
  png_read_update_info(p.png, p.info)
  let channels = png_get_channels(p.png, p.info)
  discard png_get_IHDR(p.png, p.info,
    addr width, addr height,
    addr bit_depth,
    addr color_type,
    addr interlace,
    addr compression,
    addr filter);
  # Check RGBA Loading
  if width <= 0 or height <= 0:
    png_error(p.png, "invalid dimensions")
  if bit_depth != 8:
    png_error(p.png, "invalid bit depth")
  if channels != 4:
    png_error(p.png, "invalid rgba type")
  # Initialize PNG Header
  p.w = PNGint32(width)
  p.h = PNGint32(height)
  p.adam7 = interlace == PNG_INTERLACE_ADAM7

proc prepareRowsPNG(p: PNGnimRead) =
  let
    stride = p.w * 4
    rows = p.h
  # Allocate Buffer Pointers
  p.buffer = cast[typeof p.buffer](alloc0(stride * rows))
  p.rows = cast[typeof p.rows](alloc0(rows * sizeof(pointer)))
  p.bytes = stride * rows
  # Locate Buffer Rows
  for row in 0 ..< rows:
    p.rows[row] = addr p.buffer[stride * row]

proc createReadPNG*(file: string): PNGnimRead =
  result = create(PNGhandleRead)
  let png = png_create_read_struct(PNG_LIBPNG_VER_STRING,
    addr result.report, cbError, cbWarning)
  let info = png_create_info_struct(png)
  let seek = open(result.file, file, fmRead)
  # Configure PNG Callbacks
  png_set_read_fn(png, result, cbReadFile)
  png_set_read_status_fn(png, cbStatus)
  # Store PNG Reading Attributes
  result.png = png
  result.info = info
  result.seek = int(seek)

proc createReadPNG*(raw: pointer, bytes: int): PNGnimRead =
  result = create(PNGhandleRead)
  let png = png_create_read_struct(PNG_LIBPNG_VER_STRING,
    addr result.report, cbError, cbWarning)
  let info = png_create_info_struct(png)
  # Configure PNG Callbacks
  png_set_read_fn(png, result, cbReadBuffer)
  png_set_read_status_fn(png, cbStatus)
  # Store PNG Reading Attributes
  result.png = png
  result.info = info
  result.raw = raw
  result.size = bytes

proc readRGBA*(p: PNGnimRead): bool =
  png_error_setjmp(p.png):
    p.useless = true
    return result
  if p.useless:
    png_error(p.png, "read finalized")
  # Prepare PNG Reading
  p.prepareReadPNG()
  p.prepareRowsPNG()
  # Read Image Buffer
  png_read_image(p.png, cast[ptr pointer](p.rows))
  png_read_end(p.png, p.info)
  # Finalize PNG Read
  p.useless = true
  result = true

proc close*(p: PNGnimRead) =
  png_destroy_read_struct(addr p.png, addr p.info, nil)
  cast[ptr PNGhandle](p).destroy()
  # Dealloc Read PNG
  dealloc(p)

# --------------------------
# libpng Nim RGB/RGBA Writer
# --------------------------

proc prepareWritePNG(p: PNGnimWrite, color_type: PNGint32) =
  const bpc: PNGbyte = 8
  let width = PNGuint32(p.w)
  let height = PNGuint32(p.h)
  # Check Valid PNG Files
  if p.seek == 0:
    png_error(p.png, "failed creating png file")
  if width <= 0 or height <= 0:
    png_error(p.png, "invalid png dimensions")
  # Set Compression Level
  if p.level in 0 .. 9:
    png_set_compression_level(p.png, p.level)
  # Set Interlace ADAM7
  var interlace = PNG_INTERLACE_NONE
  if p.adam7: interlace = PNG_INTERLACE_ADAM7
  # Configure IHDR Basic Information
  png_set_IHDR(p.png, p.info,
    width, height, 8, color_type, interlace,
    PNG_COMPRESSION_TYPE_BASE,
    PNG_FILTER_TYPE_BASE)
  # Configure Bit Depth
  var sbit: PNGcolor8
  sbit.red = bpc
  sbit.green = bpc
  sbit.blue = bpc
  sbit.alpha = bpc
  png_set_sBIT(p.png, p.info, addr sbit)
  png_write_info(p.png, p.info)
  png_set_packing(p.png)
  # Downgrade RGBA to RGB
  if color_type == PNG_COLOR_TYPE_RGB:
    png_set_filler(p.png, 0, PNG_FILLER_AFTER)

proc createWritePNG*(file: string, w, h: PNGint32): PNGnimWrite =
  result = create(PNGhandleWrite)
  let png = png_create_write_struct(PNG_LIBPNG_VER_STRING,
    addr result.report, cbError, cbWarning)
  let info = png_create_info_struct(png)
  let seek = open(result.file, file, fmWrite)
  # Configure PNG Callbacks
  png_set_write_fn(png, result, cbWriteFile, cbWriteFlush)
  png_set_write_status_fn(png, cbStatus)
  # Store PNG Writing Attributes
  result.png = png
  result.info = info
  result.level = PNG_ZLIB_DEFAULT
  result.seek = int(seek)
  # Store PNG Writing Dimensions
  result.w = w
  result.h = h
  # Allocate PNG Writing Buffers
  cast[PNGnimRead](result).prepareRowsPNG()

proc writeRGBA*(p: PNGnimWrite): bool =
  png_error_setjmp(p.png):
    p.useless = true
    return result
  if p.useless:
    png_error(p.png, "write finalized")
  # Prepare PNG Image and Write Image
  p.prepareWritePNG(PNG_COLOR_TYPE_RGB_ALPHA)
  png_write_image(p.png, cast[ptr pointer](p.rows))
  png_write_end(p.png, p.info)
  # Finalize PNG Write
  p.useless = true
  result = true

proc writeRGB*(p: PNGnimWrite): bool =
  png_error_setjmp(p.png):
    p.useless = true
    return result
  if p.useless:
    png_error(p.png, "write finalized")
  # Prepare PNG Image and Write Image
  p.prepareWritePNG(PNG_COLOR_TYPE_RGB)
  png_write_image(p.png, cast[ptr pointer](p.rows))
  png_write_end(p.png, p.info)
  # Finalize PNG Write
  p.useless = true
  result = true

proc close*(p: PNGnimWrite) =
  png_destroy_write_struct(addr p.png, addr p.info)
  cast[ptr PNGhandle](p).destroy()
  # Dealloc Write PNG
  dealloc(p)
