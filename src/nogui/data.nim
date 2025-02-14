from os import `/`, getAppDir, dirExists
from std/compilesettings import 
  querySetting, SingleValueSetting
# TODO: Use fontconfig for extra fonts
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

var dataPath = default(string)
proc checkDataPath() =
  const project = querySetting(projectName)
  if len(dataPath) > 0: return
  let app = getAppDir()
  # Check Relative Path
  var path = app / "data"
  if not dirExists(path):
    const projectData = project & ".data"
    path = app / projectData
  # try find on /usr/share/<projectname>
  when defined(posix):
    const unixPath = "/usr/share" / project
    if not dirExists(path):
      path = unixPath
  # Check Actually Found
  if dirExists(path):
    dataPath = move path
    return
  # Crash at Data Folder not Found
  log(lvError, "failed locate application data")
  quit(65535)

proc toDataPath*(path: string): string =
  checkDataPath(); dataPath / path

# -----------------------
# Icon Chunk Loading Type
# -----------------------

type
  CTXChunkHeader = object
    bytes*: cuint
    w*, h*, fit*: cshort
    channels*: cshort
    # Hotspot Position
    ox*, oy*: cshort
  CTXChunkBuffer = ptr UncheckedArray[byte]
  CTXChunkIcon* = object
    info*: ptr CTXChunkHeader
    buffer*: CTXChunkBuffer
  # Packed Icons Reader
  CTXPackedIcons* = ref object
    handle: File
    allocated: int
    # Current Icon Buffer
    header*: CTXChunkHeader
    buffer*: CTXChunkBuffer

# Ordered Icon Identifiers
type CTXIconID* = distinct uint16
type CTXCursorID* = distinct uint16
# Empty Icon Identifier
const CTXIconEmpty* = CTXIconID(65535)
proc `==`*(a, b: CTXIconID): bool {.borrow.}
proc `==`*(a, b: CTXCursorID): bool {.borrow.}

# --------------------------
# Icon Chunk Loading Prepare
# --------------------------

proc newPacked(filename: string, signature: uint64): CTXPackedIcons =
  new result
  # Try Open File
  let path = toDataPath(filename)
  if not open(result.handle, path, fmRead):
    raise newException(IOError, path & " cannot be open")
  # Read File Signature
  var sig: uint64
  if readBuffer(result.handle, addr sig, 8) != 8 or 
    sig != signature: # Check if is Valid Signature
      raise newException(IOError, path & " is not valid")

proc newIcons*(filename: string): CTXPackedIcons =
  newPacked(filename, 0x4955474f4e'u64) # 'NOGUI   '

proc newCursors*(filename: string): CTXPackedIcons =
  newPacked(filename, 0x5255434955474f4e'u64) # 'NOGUICUR'

# -----------------------
# Icon Chunk Loading Read
# -----------------------

proc bytesIcon(pack: CTXPackedIcons, bytes: int): CTXChunkBuffer =
  if bytes > pack.allocated:
    pack.allocated = bytes
    # We dont need prev data
    let prev = pack.buffer
    if not isNil(prev):
      dealloc(prev)
    pack.buffer = cast[CTXChunkBuffer](alloc bytes)
  # Return Current Buffer
  pack.buffer

iterator icons*(pack: CTXPackedIcons): CTXChunkIcon =
  let
    handle = pack.handle
    info = addr pack.header
  # File Chunk Reader
  var result: CTXChunkIcon
  result.info = info
  # Read Chunk and Write a PNG
  const headSize = sizeof(CTXChunkHeader)
  while readBuffer(handle, info, headSize) == headSize:
    let 
      bytes = int info.bytes
      data = bytesIcon(pack, bytes)
    if readBuffer(handle, addr data[0], bytes) == bytes:
      result.buffer = data
      yield result
  # Dealloc Buffer and File
  dealloc(pack.buffer)
  close(pack.handle)

# ------------------------
# Freetype 2 Font Creation
# ------------------------

proc newFont*(ft2: FT2Library, font: string, size: cint): FT2Face =
  let path = toDataPath(font)
  # Load Default Font File using FT2 Loader
  if ft2_newFace(ft2, cstring path, 0, addr result) != 0:
    log(lvError, "failed loading font file: ", path)
  # Set Size With 96 of DPI, DPI Awareness is confusing
  if ft2_setCharSize(result, 0, size shl 6, 96, 96) != 0:
    log(lvWarning, "font size was setted not properly")

# ----------------------
# OpenGL Shader Creation
# ----------------------

proc compileShader*(shader: string, kind: GLenum): GLuint =
  let path = toDataPath("glsl")
  result = glCreateShader(kind)
  try: # Load Vertex Shader from File
    let buffer = readFile(path / shader)
    let source = cast[cstring](addr buffer[0])
    glShaderSource(result, 1, cast[cstringArray](addr source), nil)
  except IOError: log(lvError, "failed loading shader:", shader)
  glCompileShader(result)
  # Check Shader Error
  var status {.noinit.}: GLint 
  glGetShaderiv(result, GL_COMPILE_STATUS, addr status)
  if status == GL_FALSE:
    var logsize {.noinit.}: GLint
    glGetShaderiv(result, GL_INFO_LOG_LENGTH, addr logsize)
    # Output Shader Compiler Error
    let buffer = newString(logsize)
    let error = cstring(buffer)
    glGetShaderInfoLog(result, logsize, addr logsize, error)
    log(lvError, "failed compiling:", shader)
    log(lvError, error)

proc newShader*(vert, frag: string): GLuint =
  let vertShader = compileShader(vert, GL_VERTEX_SHADER)
  let fragShader = compileShader(frag, GL_FRAGMENT_SHADER)
  # Create Shader Program
  result = glCreateProgram()
  glAttachShader(result, vertShader)
  glAttachShader(result, fragShader)
  # Link Shader Program
  glLinkProgram(result)
  var status {.noinit.}: GLint
  glGetProgramiv(result, GL_LINK_STATUS, addr status)
  if status == GL_FALSE:
    var logsize {.noinit.}: GLint
    glGetProgramiv(result, GL_INFO_LOG_LENGTH, addr logsize)
    # Output Shader Link Error
    let buffer = newString(logsize)
    let error = cstring(buffer)
    glGetProgramInfoLog(result, logsize, addr logsize, error)
    log(lvError, "failed linking:", vert, frag)
    log(lvError, error)
  # Clean up Temporals
  glDeleteShader(vertShader)
  glDeleteShader(fragShader)
