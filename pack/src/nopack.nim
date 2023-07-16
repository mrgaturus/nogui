from os import fileExists, `/`
from strutils import parseInt, split, endsWith

{.compile: "nopack.c".}
{.push header: "nopack.h".}

type
  ImageChunk {.importc: "image_chunk_t".} = object
    bytes: cuint
    w, h, fit: cshort
    channels: cshort
    # Allocated Chunk
    pad0: cuint
    buffer: UncheckedArray[byte]
  PImageChunk = ptr ImageChunk

{.push importc.}

proc nopack_load_svg(filename: cstring, fit: cint, isRGBA: cint): PImageChunk
proc nopack_load_bitmap(filename: cstring, fit: cint, isRGBA: cint): PImageChunk
proc nopack_load_dealloc(chunk: PImageChunk)

{.pop.} # importc
{.pop.} # header

# ------------
# Chunk Writer
# ------------

{.push raises: [IOError].}

proc iconlist(filename: string): File =
  if not open(result, filename, fmRead):
    raise newException(IOError, filename & " not found")

proc packfile(filename: string): File =
  if not open(result, filename, fmWrite):
    raise newException(IOError, filename & " not writtable")

proc header(file: File, isRGBA: bool) =
  const
    NOGUIRgbSignature = 0x4247524955474f4e'u64 # "NOGUIRGB"
    NOGUIAlphaSignature = 0x4955474f4e'u64 # "NOGUI   "
    UInt64Size = sizeof(uint64)
  # Write Header to File
  var signature: uint64
  signature = if isRGBA:
    NOGUIRgbSignature
  else: NOGUIAlphaSignature
  if writeBuffer(file, addr signature, sizeof UInt64Size) != UInt64Size:
    raise newException(IOError, "illformed signature")

proc rasterize(filename: string, fit: cshort, isRGBA: bool): PImageChunk =
  # Check if File Exists
  if not fileExists(filename):
    raise newException(IOError, "not found")
  # Check Filename type
  result = if filename.endsWith(".svg"):
    nopack_load_svg(filename, fit, cint isRGBA)
  else: nopack_load_bitmap(filename, fit, cint isRGBA)
  # Check if file was loaded
  if isNil(result):
    raise newException(IOError, filename & " is invalid")

proc write(file: File, chunk: PImageChunk) =
  let bytes = sizeof(ImageChunk) + int(chunk.bytes)
  # Copy Chunk to File
  if writeBuffer(file, chunk, bytes) != bytes:
    raise newException(IOError, "writing is illformed")

proc info(line: string): tuple[file: string, fit: cshort] =
  let s = split(line, " : ")
  result.file = "icons" / s[0]
  # Extract Size
  try:
    result.fit = cshort parseInt s[1]
  except ValueError:
    raise newException(IOError, result.file & " invalid fit size")

proc pack(isRGBA: bool) =
  # Prepare Icons File
  var 
    list = iconlist("icons" / "icons.list")
    pack = packfile("data" / "icons.dat")
  # Write Pack Signature
  header(pack, isRGBA)
  # Write Each File
  for line in lines(list):
    let 
      info = info(line)
      chunk = rasterize(info.file, info.fit, isRGBA)
    echo "[PACKED] " & line
    # Write Chunk to File
    write(pack, chunk)
    nopack_load_dealloc(chunk)

{.pop.} # raises

# ---------
# Main Proc
# ---------

proc main() =
  echo "nogui icon packer v1"
  echo "mrgaturus 2023"
  try: pack(false)
  except IOError as error:
    echo "[ERROR] ", error.msg
    quit(65535)

when isMainModule:
  main()
