from math import sqrt, ceil, nextPowerOfTwo
# Import Libs
import ../libs/gl
import ../libs/ft2
import ../loader

type
  SKYNode = object
    x, y, w: int16
  # Atlas Objects
  TEXIcon = object
    x1*, x2*, y1*, y2*: int16
    # Bitmap Dimensions
    w*, h*, fit*: int16
  TEXGlyph = object
    x1*, x2*, y1*, y2*: int16 # UV Coords
    xo*, yo*, advance*: int16 # Positioning
    # Bitmap Dimensions
    w*, h*: int16
  # Buffer Mapping
  BUFMapping = ptr UncheckedArray[byte]
  BUFStatus = enum # Bitmap Buffer Status
    bufNormal, bufDirty, bufResize
  # Atlas Object
  CTXAtlas* = ref object
    # FT2 FONT FACE
    face: FT2Face
    # SKYLINE BIN PACKING
    w, h: int32 # Dimensions
    nodes: seq[SKYNode]
    # ICONS INFORMATION
    icons: seq[TEXIcon]
    # GLYPHS INFORMATION
    lookup: seq[uint16]
    glyphs: seq[TEXGlyph]
    # GLYPH ATLAS BITMAP
    buffer: seq[byte]
    status: BUFStatus
    x1, x2, y1, y2: int16
    # OPENGL INFORMATION
    texID*: uint32 # Texture
    whiteU*, whiteV*: int16
    rw*, rh*: float32 # Normalized
    # TODO: create a font manager
    baseline*: int16

# -----------------------------
# Charsets Range for Preloading
# -----------------------------

let # Charset Common Ranges for Preloading
  csLatin* = # English, Spanish, etc.
    [0x0020'u16, 0x00FF'u16]
  csKorean* = # All Korean letters
    [0x0020'u16, 0x00FF'u16,
     0x3131'u16, 0x3163'u16,
     0xAC00'u16, 0xD79D'u16]
  csJapaneseChinese* = # Hiragana, Katakana
    [0x0020'u16, 0x00FF'u16,
     0x2000'u16, 0x206F'u16,
     0x3000'u16, 0x30FF'u16,
     0x31F0'u16, 0x31FF'u16,
     0xFF00'u16, 0xFFEF'u16]
  csCyrillic* = # Russian, Euraska, etc.
    [0x0020'u16, 0x00FF'u16,
     0x0400'u16, 0x052F'u16,
     0x2DE0'u16, 0x2DFF'u16,
     0xA640'u16, 0xA69F'u16]
  # Charsets from dear imgui

# -------------------------------------------
# FONTSTASH'S ATLAS SKYLINE BIN PACKING PROCS
# -------------------------------------------

proc rectFits(atlas: CTXAtlas, idx: int32, w,h: int16): int16 =
  if atlas.nodes[idx].x + w > atlas.w: return -1
  var # Check if there is enough space at location i
    y = atlas.nodes[idx].y
    spaceLeft = w
    i = idx
  while spaceLeft > 0:
    if i == len(atlas.nodes): 
      return -1
    y = max(y, atlas.nodes[i].y)
    if y + h > atlas.h: 
      return -1
    spaceLeft -= atlas.nodes[i].w
    inc(i)
  return y # Yeah, Rect Fits

proc addSkylineNode(atlas: CTXAtlas, idx: int32, x,y,w,h: int16) =
  block: # Add New Node, not OOM checked
    var node: SKYNode
    node.x = x; node.y = y+h; node.w = w
    atlas.nodes.insert(node, idx)
  var i = idx+1 # New Iterator
  # Delete skyline segments that fall under the shadow of the new segment
  while i < len(atlas.nodes):
    let # Prev Node and i-th Node
      pnode = addr atlas.nodes[i-1]
      inode = addr atlas.nodes[i]
    if inode.x < pnode.x + pnode.w:
      let shrink =
        pnode.x - inode.x + pnode.w
      inode.x += shrink
      inode.w -= shrink
      if inode.w <= 0:
        atlas.nodes.delete(i)
        dec(i) # Reverse i-th
      else: break
    else: break
    inc(i) # Next Node
  # Merge same height skyline segments that are next to each other
  i = 0 # Reset Iterator
  while i < high(atlas.nodes):
    let # Next Node and i-th Node
      nnode = addr atlas.nodes[i+1]
      inode = addr atlas.nodes[i]
    if inode.y == nnode.y:
      inode.w += nnode.w
      atlas.nodes.delete(i+1)
      dec(i) # Reverse i-th
    inc(i) # Next Node

proc pack(atlas: CTXAtlas, w, h: int16): tuple[x, y: int16] =
  var # Initial Best Fits
    bestIDX = -1'i32
    bestX, bestY = -1'i16
  block: # Find Best Fit
    var # Temporal Vars
      bestH = atlas.h
      bestW = atlas.w
      i: int32 = 0
    while i < len(atlas.nodes):
      let y = atlas.rectFits(i, w, h)
      if y != -1: # Fits
        let node = addr atlas.nodes[i]
        if y + h < bestH or y + h == bestH and node.w < bestW:
          bestIDX = i
          bestW = node.w
          bestH = y + h
          bestX = node.x
          bestY = y
      inc(i) # Next Node
  if bestIDX != -1: # Can be packed
    addSkylineNode(atlas, bestIDX, bestX, bestY, w, h)
    # Return Packing Position
    result.x = bestX; result.y = bestY
  else: result.x = -1; result.y = -1

# -----------------------
# ATLAS BUFFER COPY PROCS
# -----------------------

proc copy(src, dst: pointer, x, y, w, h, stride: int) =
  let 
    src = cast[BUFMapping](src)
    dst = cast[BUFMapping](dst)
    bytes = w * h
  var
    loc0: int
    loc1 = y * stride + x
  while loc0 < bytes:
    copyMem(addr dst[loc1], addr src[loc0], w)
    # Step Stride
    loc1 += stride
    loc0 += w

proc batch(atlas: CTXAtlas, src: pointer, w, h: int) =
  let 
    src = cast[BUFMapping](src)
    l = len(atlas.buffer)
    bytes = w * h
  # Extend Buffer
  if bytes > 0:
    setLen(atlas.buffer, l + bytes)
    copyMem(addr atlas.buffer[l], src, bytes)

proc expand(atlas: CTXAtlas) =
  let stride = atlas.w
  # Expand Atlas To Next Power Of Two
  if atlas.w == atlas.h:
    atlas.w *= 2; atlas.rw *= 0.5
    atlas.nodes.add SKYNode(
      x: int16 stride, y: 0, 
      w: int16 atlas.w - stride)
  else: atlas.h *= 2; atlas.rh *= 0.5
  # Move Buffer to New Seq
  var 
    dest: seq[byte]
    i, k: int32
  dest.setLen(atlas.w * atlas.h)
  # Copy Atlas to New Location
  while i < len(atlas.buffer):
    copyMem(addr dest[k], addr atlas.buffer[i], stride)
    i += stride; k += atlas.w
  # Replace Buffer With New One
  atlas.buffer = move dest

# ---------------------------
# ATLAS GLYPH RENDERING PROCS
# ---------------------------

proc renderIcons(atlas: CTXAtlas, pack: GUIPackedIcons) =
  # Iterate Each Icon
  for icon in icons(pack):
    let info = icon.info
    # Copy Icon to Temporal Batch
    atlas.batch(icon.buffer, info.w, info.h)
    atlas.icons.add TEXIcon(
      w: info.w, 
      h: info.h, 
      fit: info.fit
    )

proc renderFallback(atlas: CTXAtlas) =
  let # Fallback Metrics
    size = atlas.baseline
    half = size shr 1
  # Add A Glyph for a white rectangle
  atlas.glyphs.add TEXGlyph(
    w: half, h: size, # W is Half Size
    xo: 1, yo: size, # xBearing, yBearing
    advance: half + 2 # *[]*
  ) # End Add Glyph to Glyph Cache
  # Alloc White Rectangle
  var i = len(atlas.buffer)
  atlas.buffer.setLen(i + half * size)
  while i < len(atlas.buffer):
    atlas.buffer[i] = high(byte); inc(i)

proc renderCharcode(atlas: CTXAtlas, code: uint16) =
  let index = ft2_getCharIndex(atlas.face, code) # Load Glyph from Global
  if index != 0 and ft2_loadGlyph(atlas.face, index, FT_LOAD_RENDER) == 0:
    let slot = atlas.face.glyph # Shorcut
    # -- Add Glyph to Glyph Cache
    atlas.glyphs.add TEXGlyph(
      # Save new dimensions, very small values
      w: cast[int16](slot.bitmap.width),
      h: cast[int16](slot.bitmap.rows),
      # Save position offsets, very small values
      xo: cast[int16](slot.bitmap_left), # xBearing
      yo: cast[int16](slot.bitmap_top), # yBearing
      advance: cast[int16](slot.advance.x shr 6)
    ) # End Add Glyph to Glyph Cache
    # --    Copy Bitmap to Temporal buffer
    let bm = addr slot.bitmap
    atlas.batch(bm.buffer, int bm.width, int bm.rows)
    # -- Save Glyph Index at Lookup
    atlas.lookup[code] = uint16(high atlas.glyphs)
  else: atlas.lookup[code] = 0xFFFF

proc renderCharset(atlas: CTXAtlas, charset: openArray[uint16]) =
  var # Charset Iterator
    s, e: uint16 # Charcode Iter
    i = 0 # Range Iter
  while i < len(charset):
    s = charset[i] # Start
    e = charset[i+1] # End
    # Check if lookup is big enough
    if int32(e) >= len(atlas.lookup):
      atlas.lookup.setLen(1 + int32 e)
    elif int32(s) >= len(atlas.lookup):
      atlas.lookup.setLen(1 + int32 s)
    # Render Charcodes one by one
    while s <= e: # Iterate Charcodes
      renderCharcode(atlas, s)
      inc(s) # Next Charcode
    i += 2 # Next Range Pair

proc renderOnDemand(atlas: CTXAtlas, code: uint16): ptr TEXGlyph =
  let index = ft2_getCharIndex(atlas.face, code) # Load Glyph From Global
  if index != 0 and ft2_loadGlyph(atlas.face, index, FT_LOAD_RENDER) == 0:
    var # Auxiliar Vars
      glyph: ptr TEXGlyph
      buffer: cstring
    block: # -- Save New Glyph to Glyphs Seq
      let slot = atlas.face.glyph # Shorcut
      # Expand Glyphs for a New Glyph
      atlas.glyphs.setLen(1 + atlas.glyphs.len)
      glyph = addr atlas.glyphs[^1]
      # Save Bitmap Dimensions
      glyph.w = cast[int16](slot.bitmap.width)
      glyph.h = cast[int16](slot.bitmap.rows)
      # Save Position Offsets
      glyph.xo = cast[int16](slot.bitmap_left)
      glyph.yo = cast[int16](slot.bitmap_top)
      glyph.advance = cast[int16](slot.advance.x shr 6)
      # Set Aux Buffer Pointer
      buffer = slot.bitmap.buffer
    block: # -- Arrange Glyph To Atlas
      var point = pack(atlas, glyph.w, glyph.h)
      if point.x < 0 or point.y < 0:
        atlas.expand()
        # Try Pack Again, Guaranted
        point = pack(atlas, glyph.w, glyph.h)
        # Mark as Invalid
        atlas.status = bufResize
      elif atlas.status == bufNormal:
        atlas.status = bufDirty
      # Save New Packed UV Coordinated to Glyph
      glyph.x1 = point.x; glyph.x2 = point.x + glyph.w
      glyph.y1 = point.y; glyph.y2 = point.y + glyph.h
      # Extend Dirty Rect
      if atlas.status == bufDirty:
        atlas.x1 = min(atlas.x1, glyph.x1)
        atlas.y1 = min(atlas.y1, glyph.y1)
        atlas.x2 = max(atlas.x2, glyph.x2)
        atlas.y2 = max(atlas.y2, glyph.y2)
    # -- Copy New Glyph To Atlas Buffer
    let 
      dst = addr atlas.buffer[0]
      stride = atlas.w
    copy(buffer, dst, glyph.x1, glyph.y1, glyph.w, glyph.h, stride)
    # -- Save Glyph Index at Lookup
    atlas.lookup[code] = uint16(high atlas.glyphs)
    glyph # Return Recently Created Glyph
  else: atlas.lookup[code] = 0xFFFF; addr atlas.glyphs[0]

# -------------------
# ATLAS CREATION PROC
# -------------------

proc arrangeAtlas(atlas: CTXAtlas) =
  # Allocate Temporal
  var img: seq[byte]; block:
    var side = len(atlas.buffer)
    side = side.float32.sqrt().ceil().int.nextPowerOfTwo()
    # Set new Atlas Diemsions
    atlas.w = cast[int32](side shl 1)
    atlas.h = cast[int32](side)
    # Set Normalized Atlas Dimensions for get MAD
    atlas.rw = 1 / atlas.w # vertex.u * uDim.w
    atlas.rh = 1 / atlas.h # vertex.v * uDim.h
    # Add Initial Skyline Node
    atlas.nodes.add SKYNode(w: int16 atlas.w)
    # Alloc Buffer with new dimensions
    img.setLen(side * side shl 1)
  # Auxiliar Pointers
  let
    dst = addr img[0]
    stride = atlas.w
    # Current Buffer Mapping
    src = cast[BUFMapping](addr atlas.buffer[0])
  var idx: int
  # Unredundant Template
  template arrange(o: typed) =
    let
      w = o.w
      h = o.h
      p = atlas.pack(w, h)
    # Copy current Glyph to Arranged
    copy(addr src[idx], dst, p.x, p.y, w, h, stride)
    # Store UV Locations
    o.x1 = p.x; o.x2 = p.x + w
    o.y1 = p.y; o.y2 = p.y + h
    # Step Source
    idx += w * h
  # Arrange Icons to Atlas
  for icon in mitems(atlas.icons):
    arrange(icon)
  # Arrange Glyphs to Atlas
  for glyph in mitems(atlas.glyphs):
    arrange(glyph)
  # Use Fallback for Locate White Pixel
  atlas.whiteU = atlas.glyphs[0].x1
  atlas.whiteV = atlas.glyphs[0].y1
  # Replace Buffer Atlas
  atlas.buffer = move img

proc newCTXAtlas*(face: FT2Face): CTXAtlas =
  new result
  # Prepare Handles
  result.face = face
  let icons = newIcons("icons.dat")
  # TODO: create a font manager
  block:
    let
      m = face.size.metrics
      baseline = m.ascender + m.descender
    result.baseline = cast[int16](baseline shr 6)
  # Batch Intitial Resources
  result.renderIcons(icons)
  result.renderFallback()
  result.renderCharset(csLatin)
  # Arrange Attlas Elements
  result.arrangeAtlas()

# ---------------------------
# ATLAS TEXTURE UPDATING PROC
# ---------------------------

proc createTexture*(atlas: CTXAtlas) =
  # TODO: move to newCTXAtlas
  # Copy Buffer to a New Texture
  glGenTextures(1, addr atlas.texID)
  glBindTexture(GL_TEXTURE_2D, atlas.texID)
  # Clamp Atlas to Edge
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, cast[GLint](GL_CLAMP_TO_EDGE))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, cast[GLint](GL_CLAMP_TO_EDGE))
  # Use Nearest Pixel Filter
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, cast[GLint](GL_NEAREST))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, cast[GLint](GL_NEAREST))
  # Swizzle pixel components to RED-RED-RED-RED
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_R, cast[GLint](GL_RED))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_G, cast[GLint](GL_RED))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_B, cast[GLint](GL_RED))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_A, cast[GLint](GL_RED))
  # Copy Arranged Bitmap Buffer to Texture
  glTexImage2D(GL_TEXTURE_2D, 0, cast[int32](GL_R8), atlas.w, atlas.h,
    0, GL_RED, GL_UNSIGNED_BYTE, addr atlas.buffer[0])
  # Unbind New Atlas Texture
  glBindTexture(GL_TEXTURE_2D, 0)

proc checkTexture*(atlas: CTXAtlas): bool =
  case atlas.status:
  of bufNormal: return false
  of bufDirty: # Has New Glyphs
    # Ajust Unpack Aligment for copy
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, atlas.w)
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, atlas.x1)
    glPixelStorei(GL_UNPACK_SKIP_ROWS, atlas.y1)
    # Copy Dirty Area to Texture
    glTexSubImage2D(GL_TEXTURE_2D, 0, atlas.x1, atlas.y1, 
      atlas.x2 - atlas.x1, atlas.y2 - atlas.y1, GL_RED, 
      GL_UNSIGNED_BYTE, addr atlas.buffer[0])
    # Reset Unpack Aligment to default
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0)
    glPixelStorei(GL_UNPACK_SKIP_ROWS, 0)
  of bufResize: # Has Been Resized
    glTexImage2D(GL_TEXTURE_2D, 0, cast[int32](GL_R8), 
      atlas.w, atlas.h, 0, GL_RED, GL_UNSIGNED_BYTE, 
      addr atlas.buffer[0]); result = true
  # Reset Dirty Texture Region
  atlas.x1 = cast[int16](atlas.w)
  atlas.y1 = cast[int16](atlas.h)
  atlas.x2 = 0; atlas.y2 = 0
  # Set Status to Normal
  atlas.status = bufNormal

# ----------------------------------
# ATLAS GLYPH AND ICONS LOOKUP PROCS
# ----------------------------------

proc glyph*(atlas: CTXAtlas, charcode: uint16): ptr TEXGlyph =
  # Check if lookup needs expand
  if int32(charcode) >= len(atlas.lookup):
    atlas.lookup.setLen(1 + int32 charcode)
  # Get Glyph Index of the lookup
  let lookup = atlas.lookup[charcode]
  case lookup # Check Found Index
  of 0: renderOnDemand(atlas, charcode)
  of 0xFFFF: addr atlas.glyphs[0]
  else: addr atlas.glyphs[lookup]

proc icon*(atlas: CTXAtlas, id: uint16): ptr TEXIcon =
  result = addr atlas.icons[id] # Get Icon UV Coords

proc info*(atlas: CTXAtlas): tuple[tex: GLuint, w, h: int32] =
  # Return Debug Info
  (atlas.texID, atlas.w, atlas.h)
