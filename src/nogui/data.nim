# Import Location Management
from os import `/`, getAppDir, dirExists
from std/compilesettings import 
  querySetting, SingleValueSetting
# TODO: Use fontconfig for extra fonts
# TODO: errors as exceptions with IOError
import logger
import libs/gl
from libs/ft2 import
  FT2Face,
  FT2Library,
  ft2_init,
  ft2_newFace,
  ft2_setCharSize

# ------------------
# Data Path Location
# ------------------

proc toDataPath(path: string): string =
  let relativePath = getAppDir() / "data"
  # Check if relative path exists
  result = relativePath / path
  when defined(posix):
    const unixPath = "/usr/share" / querySetting(projectName)
    # try find on /usr/share/<projectname>
    if not dirExists(relativePath):
      result = unixPath / path

# -----------------------
# Icon Data Loading Procs
# -----------------------

type
  CTXHeaderIcon = object
    bytes*: cuint
    w*, h*, fit*: cshort
    channels*: cshort
    # Allocated Chunk
    pad0: cuint
  CTXBufferIcon = ptr UncheckedArray[byte]
  CTXChunkIcon* = object
    info*: ptr CTXHeaderIcon
    buffer*: CTXBufferIcon
  CTXPackedIcons* = ref object
    handle: File
    allocated: int
    # Current Icon Buffer
    header*: CTXHeaderIcon
    buffer*: CTXBufferIcon
  # Usable Icon ID Const
  CTXIconID* = distinct int32

proc newIcons*(filename: string): CTXPackedIcons =
  new result
  # Try Open File
  let path = toDataPath(filename)
  if not open(result.handle, path, fmRead):
    raise newException(IOError, path & " cannot be open")
  # Read File Signature
  var signature: uint64
  if readBuffer(result.handle, addr signature, 8) != 8 or 
    signature != 0x4955474f4e'u64:
      raise newException(IOError, path & " is not valid")

proc bytesIcon(pack: CTXPackedIcons, bytes: int): CTXBufferIcon =
  if bytes > pack.allocated:
    pack.allocated = bytes
    # We dont need prev data
    let prev = pack.buffer
    if not isNil(prev):
      dealloc(prev)
    pack.buffer = cast[CTXBufferIcon](alloc bytes)
  # Return Current Buffer
  pack.buffer

iterator icons*(pack: CTXPackedIcons): CTXChunkIcon =
  let
    handle = pack.handle
    info = addr pack.header
  # Chunk Yiedler
  var result: CTXChunkIcon
  result.info = info
  # Read Chunk and Write a PNG
  const headSize = sizeof CTXHeaderIcon
  while readBuffer(handle, info, headSize) == headSize:
    let 
      bytes = int info.bytes
      data = bytesIcon(pack, bytes)
    if readBuffer(handle, addr data[0], bytes) == bytes:
      result.buffer = data
      yield result
  # We Can Close File
  close(pack.handle)
  # Free Temporal Buffer
  dealloc(pack.buffer)

# -----------------------------
# Freetype 2 Face Creation Proc
# -----------------------------

proc newFont*(ft2: FT2Library, font: string, size: cint): FT2Face =
  let path = toDataPath(font)
  # Load Default Font File using FT2 Loader
  if ft2_newFace(ft2, cstring path, 0, addr result) != 0:
    log(lvError, "failed loading font file: ", path)
  # Set Size With 96 of DPI, DPI Awareness is confusing
  if ft2_setCharSize(result, 0, size shl 6, 96, 96) != 0:
    log(lvWarning, "font size was setted not properly")

# --------------------
# Shader Creation Proc
# --------------------

proc newShader*(vert, frag: string): GLuint =
  let path = toDataPath("glsl")
  var # Prepare Vars
    vertShader = glCreateShader(GL_VERTEX_SHADER)
    fragShader = glCreateShader(GL_FRAGMENT_SHADER)
    buffer: string
    bAddr: cstring
    success: GLint
  try: # -- LOAD VERTEX SHADER
    buffer = readFile(path / vert)
    bAddr = cast[cstring](addr buffer[0])
  except IOError: log(lvError, "failed loading shader: ", vert)
  glShaderSource(vertShader, 1, cast[cstringArray](addr bAddr), nil)
  try: # -- LOAD FRAGMENT SHADER
    buffer = readFile(path / frag)
    bAddr = cast[cstring](addr buffer[0])
  except IOError: log(lvError, "failed loading shader: ", frag)
  glShaderSource(fragShader, 1, cast[cstringArray](addr bAddr), nil)
  # -- COMPILE SHADERS
  glCompileShader(vertShader)
  glCompileShader(fragShader)
  # -- CHECK SHADER ERRORS
  glGetShaderiv(vertShader, GL_COMPILE_STATUS, addr success)
  if not success.bool:
    log(lvError, "failed compiling: ", vert)
  glGetShaderiv(fragShader, GL_COMPILE_STATUS, addr success)
  if not success.bool:
    log(lvError, "failed compiling: ", frag)
  # -- CREATE PROGRAM
  result = glCreateProgram()
  glAttachShader(result, vertShader)
  glAttachShader(result, fragShader)
  glLinkProgram(result)
  # -- CLEAN UP TEMPORALS
  glDeleteShader(vertShader)
  glDeleteShader(fragShader)
