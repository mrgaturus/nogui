# Math and Fast Math Modules
from math import sin, cos, PI
from ../values import
  fastSqrt, invSqrt,
  guiProjection
# Data Loader
from ../data import 
  newShader, CTXIconID, CTXIconEmpty, `==`
from ../utf8 import runes16
# Texture Atlas
import atlas
import metrics
# OpenGL 3.2+
import ../libs/gl

const 
  STRIDE_SIZE = # 16bytes
    sizeof(float32) * 2 + # XY
    sizeof(int16) * 2 + # UV
    sizeof(uint32) # RGBA
type
  # RENDER PRIMITIVES
  CTXColor* = uint32
  CTXPoint* = object
    x*, y*: float32
  CTXRect* = object
    x*, y*, xw*, yh*: float32
  # Clip Levels
  CTXCommand = object
    offset, base, size: int32
    texID: GLuint
    clip: GUIRect
  # Vertex Format XYUVRGBA 16-byte
  CTXVertex {.packed.} = object
    x, y: float32 # Position
    u, v: int16 # Not Normalized UV
    color: uint32 # Color
  CTXVertexMap = # Vertexs
    ptr UncheckedArray[CTXVertex]
  CTXElementMap = # Elements
    ptr UncheckedArray[uint16]
  # Allocated Buffers
  CTXRender* = object
    # Shader Program
    program: GLuint
    uPro, uDim: GLint
    # Frame viewport cache
    vWidth, vHeight: int32
    vCache: array[16, float32]
    # Atlas & Buffer Objects
    atlas: CTXAtlas
    vao, ebo, vbo: GLuint
    # Color and Clips
    color, colorAA: uint32
    clip: GUIClipping
    # Vertex index
    size, cursor: uint16
    # Write Pointers
    pCMD: ptr CTXCommand
    pVert: CTXVertexMap
    pElem: CTXElementMap
    # Allocated Buffer Data
    cmds: seq[CTXCommand]
    elements: seq[uint16]
    verts: seq[CTXVertex]

# ----------------------------
# GUI PRIMITIVE CREATION PROCS
# ----------------------------

proc rgba*(r, g, b, a: uint8): CTXColor {.compileTime.} =
  result = r or (g shl 8) or (b shl 16) or (a shl 24)

proc rect*(x, y, w, h: int32): CTXRect {.inline.} =
  result.x = float32(x) 
  result.y = float32(y)
  result.xw = float32(x + w) 
  result.yh = float32(y + h)

proc rect*(r: GUIRect): CTXRect =
  result.x = float32(r.x)
  result.y = float32(r.y)
  result.xw = float32(r.x + r.w)
  result.yh = float32(r.y + r.h)

proc point*(x, y: float32): CTXPoint {.inline.} =
  result.x = x; result.y = y

proc point*(x, y: int32): CTXPoint {.inline.} =
  result.x = float32(x)
  result.y = float32(y)

proc normal*(a, b: CTXPoint): CTXPoint =
  result.x = a.y - b.y
  result.y = b.x - a.x
  let norm = invSqrt(
    result.x * result.x + 
    result.y * result.y)
  # Normalize Point
  result.x *= norm
  result.y *= norm

# -------------------------
# GUI CANVAS CREATION PROCS
# -------------------------

proc newCTXRender*(atlas: CTXAtlas): CTXRender =
  # -- Set Texture Atlas
  result.atlas = atlas
  # -- Create new Program
  result.program = newShader("gui.vert", "gui.frag")
  # Use Program for Define Uniforms
  glUseProgram(result.program)
  # Define Projection and Texture Uniforms
  result.uPro = glGetUniformLocation(result.program, "uPro")
  result.uDim = glGetUniformLocation(result.program, "uDim")
  # Set Default Uniforms Values: Texture Slot, Atlas Dimension
  glUniform1i glGetUniformLocation(result.program, "uTex"), 0
  glUniform2f(result.uDim, result.atlas.rw, result.atlas.rh)
  # Unuse Program
  glUseProgram(0)
  # -- Gen VAOs and Batch VBO
  glGenVertexArrays(1, addr result.vao)
  glGenBuffers(2, addr result.ebo)
  # Bind Batch VAO and VBO
  glBindVertexArray(result.vao)
  glBindBuffer(GL_ARRAY_BUFFER, result.vbo)
  # Bind Elements Buffer to current VAO
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, result.ebo)
  # Vertex Attribs XYVUVRGBA 20bytes
  glVertexAttribPointer(0, 2, cGL_FLOAT, false, STRIDE_SIZE, 
    cast[pointer](0)) # VERTEX
  glVertexAttribPointer(1, 2, cGL_SHORT, false, STRIDE_SIZE, 
    cast[pointer](sizeof(float32)*2)) # UV COORDS
  glVertexAttribPointer(2, 4, GL_UNSIGNED_BYTE, true, STRIDE_SIZE, 
    cast[pointer](sizeof(float32)*2 + sizeof(int16)*2)) # COLOR
  # Enable Vertex Attribs
  glEnableVertexAttribArray(0)
  glEnableVertexAttribArray(1)
  glEnableVertexAttribArray(2)
  # Unbind VAO and VBO
  glBindBuffer(GL_ARRAY_BUFFER, 0)
  glBindVertexArray(0)

# --------------------------
# GUI RENDER PREPARING PROCS
# --------------------------

proc begin*(ctx: var CTXRender) =
  # Use GUI Program
  glUseProgram(ctx.program)
  # Disable 3D OpenGL Flags
  glDisable(GL_CULL_FACE)
  glDisable(GL_DEPTH_TEST)
  glDisable(GL_STENCIL_TEST)
  # Enable Scissor Test
  glEnable(GL_SCISSOR_TEST)
  # Enable Alpha Blending
  glEnable(GL_BLEND)
  glBlendEquation(GL_FUNC_ADD)
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  # Bind VAO and VBO
  glBindVertexArray(ctx.vao)
  glBindBuffer(GL_ARRAY_BUFFER, ctx.vbo)
  # Modify Only Texture 0
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, ctx.atlas.texID)

proc viewport*(ctx: var CTXRender, w, h: int32) =
  # Set Viewport to New Size
  glViewport(0, 0, w, h)
  # Use GUI Program
  glUseProgram(ctx.program)
  # Change GUI Projection Matrix
  guiProjection(addr ctx.vCache, 
    float32 w, float32 h)
  # Upload GUI Projection Matrix
  glUniformMatrix4fv(ctx.uPro, 1, false,
    cast[ptr float32](addr ctx.vCache))
  # Unuse GUI Program
  glUseProgram(0)
  # Save New Viewport Sizes
  ctx.vWidth = w; ctx.vHeight = h

proc clear(ctx: var CTXRender) =
  # Reset Current CMD
  ctx.pCMD = nil
  # Clear Buffers
  setLen(ctx.cmds, 0)
  setLen(ctx.elements, 0)
  setLen(ctx.verts, 0)
  # Clear Clipping Levels
  ctx.clip.clear()
  ctx.color = 0

proc render*(ctx: var CTXRender) =
  if checkTexture(ctx.atlas): # Check if was Resized
    glUniform2f(ctx.uDim, ctx.atlas.rw, ctx.atlas.rh)
  # Upload Elements
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, 
    len(ctx.elements)*sizeof(uint16),
    addr ctx.elements[0], GL_STREAM_DRAW)
  # Upload Verts
  glBufferData(GL_ARRAY_BUFFER,
    len(ctx.verts)*sizeof(CTXVertex),
    addr ctx.verts[0], GL_STREAM_DRAW)
  # Draw Clipping Commands
  for cmd in mitems(ctx.cmds):
    glScissor( # Clip Region
      cmd.clip.x, ctx.vHeight - cmd.clip.y - cmd.clip.h, 
      cmd.clip.w, cmd.clip.h) # Clip With Correct Y
    if cmd.texID == 0: # Use Atlas Texture
      glDrawElementsBaseVertex( # Draw Command
        GL_TRIANGLES, cmd.size, GL_UNSIGNED_SHORT,
        cast[pointer](cmd.offset * sizeof(uint16)),
        cmd.base) # Base Vertex Index
    else: # Use CMD Texture This Time
      # Change Texture and Use Normalized UV
      glBindTexture(GL_TEXTURE_2D, cmd.texID)
      glUniform2f(ctx.uDim, 1.0'f32, 1.0'f32)
      # Draw Texture Quad using Triangle Strip
      glDrawArrays(GL_TRIANGLE_STRIP, cmd.base, 4)
      # Back to Atlas Texture with Unnormalized UV
      glBindTexture(GL_TEXTURE_2D, ctx.atlas.texID)
      glUniform2f(ctx.uDim, ctx.atlas.rw, ctx.atlas.rh)
  ctx.clear() # Clear Render State

proc finish*() =
  # Unbind Texture and VAO
  glBindTexture(GL_TEXTURE_2D, 0)
  glBindBuffer(GL_ARRAY_BUFFER, 0)
  glBindVertexArray(0)
  # Disable Scissor and Blend
  glDisable(GL_SCISSOR_TEST)
  glDisable(GL_BLEND)
  # Unbind Program
  glUseProgram(0)

# ---------------------------
# GUI CLIP/COLOR LEVELS PROCS
# ---------------------------

proc push*(ctx: ptr CTXRender, rect: var GUIRect) =
  # Reset Current CMD
  ctx.pCMD = nil
  ctx.clip.push(rect)

proc pop*(ctx: ptr CTXRender) {.inline.} =
  # Reset Current CMD
  ctx.pCMD = nil
  ctx.clip.pop()

proc color*(ctx: ptr CTXRender, color: uint32) {.inline.} =
  ctx.color = color # Normal Solid Color
  ctx.colorAA = color and 0xFFFFFF # Antialiased

# ------------------------
# GUI PAINTER HELPER PROCS
# ------------------------

proc addCommand(ctx: ptr CTXRender) =
  # Reset Cursor
  ctx.size = 0
  # Create New Command
  var cmd: CTXCommand
  cmd.offset = int32 len(ctx.elements)
  cmd.base = int32 len(ctx.verts)
  cmd.clip = ctx.clip.peek()
  # Add New Command
  ctx.cmds.add(cmd)
  ctx.pCMD = addr ctx.cmds[^1]

proc addVerts*(ctx: ptr CTXRender, vSize, eSize: int32) =
  # Create new Command if is reseted
  if isNil(ctx.pCMD):
    addCommand(ctx)
  # Set New Vertex and Elements Lenght
  ctx.verts.setLen(ctx.verts.len + vSize)
  ctx.elements.setLen(ctx.elements.len + eSize)
  # Add Elements Count to CMD
  ctx.pCMD.size += eSize
  # Set Write Pointers
  ctx.pVert = cast[CTXVertexMap](addr ctx.verts[^vSize])
  ctx.pElem = cast[CTXElementMap](addr ctx.elements[^eSize])
  # Set Current Vertex Index
  ctx.cursor = ctx.size
  ctx.size += uint16(vSize)

# ----------------------
# GUI DRAWING TEMPLATES
# ----------------------

## X,Y,WHITEU,WHITEV,COLOR
proc vertex*(ctx: ptr CTXRender; i: int32, x, y: float32) {.inline.} =
  let vert = addr ctx.pVert[i]
  vert.x = x # Position X
  vert.y = y # Position Y
  vert.u = ctx.atlas.whiteU # White U
  vert.v = ctx.atlas.whiteV # White V
  vert.color = ctx.color # Color RGBA

## X,Y,WHITEU,WHITEV,COLORAA
proc vertexAA*(ctx: ptr CTXRender; i: int32, x, y: float32) {.inline.} =
  let vert = addr ctx.pVert[i]
  vert.x = x # Position X
  vert.y = y # Position Y
  vert.u = ctx.atlas.whiteU # White U
  vert.v = ctx.atlas.whiteV # White V
  vert.color = ctx.colorAA # Color Antialias

# X,Y,U,V,COLOR
proc vertexUV*(ctx: ptr CTXRender; i: int32; x, y: float32; u, v: int16) {.inline.} =
  let vert = addr ctx.pVert[i]
  vert.x = x # Position X
  vert.y = y # Position Y
  vert.u = u # Tex U
  vert.v = v # Tex V
  vert.color = ctx.color # Color RGBA

# X,Y,COLOR | PUBLIC
proc vertexCOL*(ctx: ptr CTXRender; i: int32; x, y: float32; color: CTXColor) {.inline.} =
  let vert = addr ctx.pVert[i]
  vert.x = x # Position X
  vert.y = y # Position Y
  vert.u = ctx.atlas.whiteU # White U
  vert.v = ctx.atlas.whiteV # White V
  vert.color = color # Color RGBA

# Last Vert Index + Offset | PUBLIC
proc triangle*(ctx: ptr CTXRender; i: int32; a, b, c: int32) {.inline.} =
  let 
    element = cast[CTXElementMap](addr ctx.pElem[i])
    cursor = ctx.cursor
  # Change Elements
  element[0] = cursor + cast[uint16](a)
  element[1] = cursor + cast[uint16](b)
  element[2] = cursor + cast[uint16](c)

proc quad*(ctx: ptr CTXRender; i: int32; a, b, c, d: int32) =
  let 
    element = cast[CTXElementMap](addr ctx.pElem[i])
    cursor = ctx.cursor
  # First Triangle
  element[0] = cursor + cast[uint16](a)
  element[1] = cursor + cast[uint16](b)
  element[2] = cursor + cast[uint16](c)
  # Second Triangle
  element[3] = cursor + cast[uint16](c)
  element[4] = cursor + cast[uint16](d)
  element[5] = cursor + cast[uint16](a)

# ---------------------------
# GUI BASIC SHAPES DRAW PROCS
# ---------------------------

proc fill*(ctx: ptr CTXRender, r: CTXRect) =
  ctx.addVerts(4, 6)
  ctx.vertex(0, r.x, r.y)
  ctx.vertex(1, r.xw, r.y)
  ctx.vertex(2, r.x, r.yh)
  ctx.vertex(3, r.xw, r.yh)
  # Elements Definition
  ctx.triangle(0, 0,1,2)
  ctx.triangle(3, 1,2,3)

proc line*(ctx: ptr CTXRender, r: CTXRect, s: float32) =
  ctx.addVerts(12, 24)
  # Top Rectangle Vertexs
  ctx.vertex(0, r.x,  r.y)
  ctx.vertex(1, r.xw, r.y)
  ctx.vertex(2, r.x,  r.y + s)
  ctx.vertex(3, r.xw, r.y + s)
  # Bottom Rectangle Vertexs
  ctx.vertex(4, r.x, r.yh)
  ctx.vertex(5, r.xw, r.yh)
  ctx.vertex(6, r.x,  r.yh - s)
  ctx.vertex(7, r.xw, r.yh - s)
  # Left Side Rectangle Vertexs
  ctx.vertex(8, r.x + s,  r.y + s)
  ctx.vertex(9, r.xw - s, r.y + s)
  # Right Side Rectangle Vertexs
  ctx.vertex(10, r.x + s,  r.yh - s)
  ctx.vertex(11, r.xw - s, r.yh - s)
  # Top Rectangle
  ctx.triangle(0, 0,1,2)
  ctx.triangle(3, 1,2,3)
  # Bottom Rectangle
  ctx.triangle(6, 4,5,6)
  ctx.triangle(9, 5,6,7)
  # Left Side Rectangle
  ctx.triangle(12, 2,8,10)
  ctx.triangle(15, 2,6,10)
  # Right Side Rectangle
  ctx.triangle(18, 3, 7,9)
  ctx.triangle(21, 11,7,9)

# --------------------------------
# CUSTOM TEXTURE ID RENDERING PROC
# --------------------------------

proc texture*(ctx: ptr CTXRender, r: CTXRect, texID: GLuint) =
  # Replace Current Command
  ctx.addCommand()
  # Alloc Texture Quad
  setLen(ctx.verts, ctx.verts.len + 4)
  ctx.pVert = # Set Pointer Cursor
    cast[CTXVertexMap](addr ctx.verts[^4])
  # Define Texture Quad Vertexs
  ctx.vertexUV(0, r.x, r.y, 0, 0)
  ctx.vertexUV(1, r.xw, r.y, 1, 0)
  ctx.vertexUV(2, r.x, r.yh, 0, 1)
  ctx.vertexUV(3, r.xw, r.yh, 1, 1)
  # Set Texture ID
  ctx.pCMD.texID = texID
  # Invalidate CMD
  ctx.pCMD = nil

# ------------------------
# ANTIALIASED SHAPES PROCS
# ------------------------

proc triangle*(ctx: ptr CTXRender, a,b,c: CTXPoint) =
  ctx.addVerts(9, 21)
  # Triangle Description
  ctx.vertex(0, a.x, a.y)
  ctx.vertex(1, b.x, b.y)
  ctx.vertex(2, c.x, c.y)
  # Elements Description
  ctx.triangle(0, 0,1,2)
  # Calculate Antialiasing
  var
    i: int32
    # Prev Position
    j = 2'i32
    l, k = 3'i32
    # Calculate
    x, y, norm: float32
  while i < 3:
    let 
      p0 = addr ctx.pVert[j]
      p1 = addr ctx.pVert[i]
    x = p0.y - p1.y
    y = p1.x - p0.x
    # Normalize Position Vector
    norm = invSqrt(x * x + y * y)
    x *= norm; y *= norm
    # Add Antialiased Vertexs to Triangle Sides
    ctx.vertexAA(k, p0.x + x, p0.y + y)
    ctx.vertexAA(k + 1, p1.x + x, p1.y + y)
    ctx.quad(l, j, k, k + 1, i)
    # Next Triangle Side
    j = i; i += 1; k += 2; l += 6

proc line*(ctx: ptr CTXRender, a,b: CTXPoint) =
  ctx.addVerts(6, 12)
  # Line Description
  ctx.vertex(0, a.x, a.y)
  ctx.vertex(1, b.x, b.y)
  var # Distances
    dx = a.y - b.y
    dy = b.x - a.x
  let # Calculate Lenght
    norm = invSqrt(dx*dx + dy*dy)
  # Normalize Distances
  dx *= norm; dy *= norm
  # Antialias Description Top
  ctx.vertexAA(2, a.x + dx, a.y + dy)
  ctx.vertexAA(3, b.x + dx, b.y + dy)
  # Antialias Description Bottom
  ctx.vertexAA(4, a.x - dx, a.y - dy)
  ctx.vertexAA(5, b.x - dx, b.y - dy)
  # Top Elements
  ctx.triangle(0, 0,1,2)
  ctx.triangle(3, 1,2,3)
  # Bottom Elements
  ctx.triangle(6, 0,1,5)
  ctx.triangle(9, 0,4,5)

proc circle*(ctx: ptr CTXRender, p: CTXPoint, r: float32) =
  let # Angle Constants
    n = int32 6 * fastSqrt(r)
    theta = 2 * PI / float32(n)
  var
    x, y: float32
    o, ox, oy: float32
    # Elements
    i, j, k: int32
  # Circle Triangles and Elements
  ctx.addVerts(n shl 1, n * 9)
  # Batch Circle Points
  while i < n:
    # Direction Normals
    ox = cos(o); oy = sin(o)
    # Point Position
    x = p.x + ox * r
    y = p.y + oy * r
    # Circle Vertex
    ctx.vertex(j, x, y)
    ctx.vertexAA(j + 1, x + ox, y + oy)
    if i + 1 < n:
      ctx.triangle(k, 0, j, j + 2)
      ctx.quad(k + 3, j, j + 1, j + 3, j + 2)
    else: # Connect Last With First
      ctx.triangle(k, 0, j, 0)
      ctx.quad(k + 3, j, j + 1, 1, 0)
    # Next Circle Triangle
    i += 1; j += 2; k += 9
    # Next Angle
    o += theta

# ----------------------------
# TEXT & ICONS RENDERING PROCS
# ----------------------------

proc text*(ctx: ptr CTXRender, x, y: int32, str: string) =
  let atlas {.cursor.} = ctx.atlas
  # Offset Y to Atlas Font Y Offset Metric
  unsafeAddr(y)[] += atlas.baseline
  # Render Text Top to Bottom
  for rune in runes16(str):
    let glyph = # Load Glyph
      atlas.glyph(rune)
    # Reserve Vertex and Elements
    ctx.addVerts(4, 6); block:
      let # Quad Coordinates
        x = float32 x + glyph.xo
        xw = x + float32 glyph.w
        y = float32 y - glyph.yo
        yh = y + float32 glyph.h
      # Quad Vertex
      ctx.vertexUV(0, x, y, glyph.x1, glyph.y1)
      ctx.vertexUV(1, xw, y, glyph.x2, glyph.y1)
      ctx.vertexUV(2, x, yh, glyph.x1, glyph.y2)
      ctx.vertexUV(3, xw, yh, glyph.x2, glyph.y2)
    # Quad Elements
    ctx.triangle(0, 0,1,2)
    ctx.triangle(3, 1,2,3)
    # To Next Glyph X Position
    unsafeAddr(x)[] += glyph.advance

proc text*(ctx: ptr CTXRender, x, y: int32, clip: CTXRect, str: string) =
  let atlas {.cursor.} = ctx.atlas
  # Offset Y to Atlas Font Y Offset Metric
  unsafeAddr(y)[] += atlas.baseline
  # Render Text Top to Bottom
  for rune in runes16(str):
    let glyph = # Load Glyph
      atlas.glyph(rune)
    var # Vertex Information
      xo = float32 x + glyph.xo
      xw = xo + float32 glyph.w
      yo = float32 y - glyph.yo
      yh = yo + float32 glyph.h
      # UV Coordinates
      uo = glyph.x1 # U Coord
      uw = glyph.x2 # U + W
      vo = glyph.y1 # V Coord
      vh = glyph.y2 # V + H
    # Is Visible on X?
    if xo > clip.xw: break
    elif xw > clip.x:
      # Clip Current Glyph
      if xo < clip.x:
        uo += int16(clip.x - xo)
        xo = clip.x # Left Point
      if xw > clip.xw:
        uw -= int16(xw - clip.xw)
        xw = clip.xw # Right Point
      # Is Clipped Vertically?
      if yo < clip.y:
        vo += int16(clip.y - yo)
        yo = clip.y # Upper Point
      if yh > clip.yh:
        vh -= int16(yh - clip.yh)
        yh = clip.yh # Botton Point
      # Reserve Vertex and Elements
      ctx.addVerts(4, 6)
      # Quad Vertex
      ctx.vertexUV(0, xo, yo, uo, vo)
      ctx.vertexUV(1, xw, yo, uw, vo)
      ctx.vertexUV(2, xo, yh, uo, vh)
      ctx.vertexUV(3, xw, yh, uw, vh)
      # Quad Elements
      ctx.triangle(0, 0,1,2)
      ctx.triangle(3, 1,2,3)
    # To Next Glyph X Position
    unsafeAddr(x)[] += glyph.advance

proc icon*(ctx: ptr CTXRender, id: CTXIconID, x, y: int32) =
  # Lookup Icon if is not Empty
  if id == CTXIconEmpty: return
  let i = icon(ctx.atlas, uint16 id)
  # Calculate Icon Metrics
  let
    x = float32 x
    y = float32 y
    xw = x + float32 i.w
    yh = y + float32 i.h
  # Reserve Vertex
  ctx.addVerts(4, 6)
  # Icon Vertex Definition
  ctx.vertexUV(0, x, y, i.x1, i.y1)
  ctx.vertexUV(1, xw, y, i.x2, i.y1)
  ctx.vertexUV(2, x, yh, i.x1, i.y2)
  ctx.vertexUV(3, xw, yh, i.x2, i.y2)
  # Elements Definition
  ctx.triangle(0, 0,1,2)
  ctx.triangle(3, 1,2,3)

proc icon*(ctx: ptr CTXRender, id: CTXIconID, r: CTXRect) =
  # Lookup Icon if is not Empty
  if id == CTXIconEmpty: return
  let i = icon(ctx.atlas, uint16 id)
  # Reserve Vertex
  ctx.addVerts(4, 6)
  # Icon Vertex Definition
  ctx.vertexUV(0, r.x, r.y, i.x1, i.y1)
  ctx.vertexUV(1, r.xw, r.y, i.x2, i.y1)
  ctx.vertexUV(2, r.x, r.yh, i.x1, i.y2)
  ctx.vertexUV(3, r.xw, r.yh, i.x2, i.y2)
  # Elements Definition
  ctx.triangle(0, 0,1,2)
  ctx.triangle(3, 1,2,3)
