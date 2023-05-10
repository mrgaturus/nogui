# Math and Fast Math Modules
from math import sin, cos, PI
from ../omath import
  fastSqrt, invSqrt,
  guiProjection
# Assets and Metrics
from config import metrics
from ../assets import newShader
from ../utf8 import runes16
# Texture Atlas
import atlas
# OpenGL 3.2+
import ../libs/gl

const 
  STRIDE_SIZE = # 16bytes
    sizeof(float32)*2 + # XY
    sizeof(int16)*2 + # UV
    sizeof(uint32) # RGBA
type
  # RENDER PRIMITIVES
  GUIColor* = uint32
  GUIRect* = object
    x*, y*, w*, h*: int32
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
    levels: seq[GUIRect]
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

proc rgba*(r, g, b, a: uint8): GUIColor {.inline.} =
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
    result.x*result.x + 
    result.y*result.y)
  # Normalize Point
  result.x *= norm
  result.y *= norm

# -------------------------
# GUI CANVAS CREATION PROCS
# -------------------------

proc newCTXRender*(): CTXRender =
  # -- Set Texture Atlas
  result.atlas = newCTXAtlas()
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
  setLen(ctx.levels, 0)
  ctx.color = 0 # Nothing Color

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

# ------------------------
# GUI PAINTER HELPER PROCS
# ------------------------

proc addCommand(ctx: ptr CTXRender) =
  # Reset Cursor
  ctx.size = 0
  # Add New Command
  ctx.cmds.add(
    CTXCommand(
      offset: int32(
        len(ctx.elements)
      ), base: int32(
        len(ctx.verts)
      ), clip: if len(ctx.levels) > 0: ctx.levels[^1]
      else: GUIRect(w: ctx.vWidth, h: ctx.vHeight)
    ) # End New CTX Command
  ) # End Add Command
  ctx.pCMD = addr ctx.cmds[^1]

proc addVerts*(ctx: ptr CTXRender, vSize, eSize: int32) =
  # Create new Command if is reseted
  if isNil(ctx.pCMD): addCommand(ctx)
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
proc vertex(ctx: ptr CTXRender; i: int32, x, y: float32) {.inline.} =
  let vert = addr ctx.pVert[i]
  vert.x = x # Position X
  vert.y = y # Position Y
  vert.u = ctx.atlas.whiteU # White U
  vert.v = ctx.atlas.whiteV # White V
  vert.color = ctx.color # Color RGBA

## X,Y,WHITEU,WHITEV,COLORAA
proc vertexAA(ctx: ptr CTXRender; i: int32, x, y: float32) {.inline.} =
  let vert = addr ctx.pVert[i]
  vert.x = x # Position X
  vert.y = y # Position Y
  vert.u = ctx.atlas.whiteU # White U
  vert.v = ctx.atlas.whiteV # White V
  vert.color = ctx.colorAA # Color Antialias

# X,Y,U,V,COLOR
proc vertexUV(ctx: ptr CTXRender; i: int32; x, y: float32; u, v: int16) {.inline.} =
  let vert = addr ctx.pVert[i]
  vert.x = x # Position X
  vert.y = y # Position Y
  vert.u = u # Tex U
  vert.v = v # Tex V
  vert.color = ctx.color # Color RGBA

# X,Y,COLOR | PUBLIC
proc vertexCOL*(ctx: ptr CTXRender; i: int32; x, y: float32; color: GUIColor) {.inline.} =
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

# -----------------------
# GUI CLIP/COLOR LEVELS PROCS
# -----------------------

proc intersect(ctx: ptr CTXRender, rect: var GUIRect): GUIRect =
  let prev = addr ctx.levels[^1]
  result.x = max(prev.x, rect.x)
  result.y = max(prev.y, rect.y)
  result.w = min(prev.x + prev.w, rect.x + rect.w) - result.x
  result.h = min(prev.y + prev.h, rect.y + rect.h) - result.y

proc push*(ctx: ptr CTXRender, rect: var GUIRect) =
  # Reset Current CMD
  ctx.pCMD = nil
  # Calcule Intersect Clip
  var clip = if len(ctx.levels) > 0:
    ctx.intersect(rect) # Intersect Level
  else: rect # First Level
  # Add new Level to Stack
  ctx.levels.add(clip)

proc pop*(ctx: ptr CTXRender) {.inline.} =
  # Reset Current CMD
  ctx.pCMD = nil
  # Remove Last CMD from Stack
  ctx.levels.setLen(max(ctx.levels.len - 1, 0))

proc color*(ctx: ptr CTXRender, color: uint32) {.inline.} =
  ctx.color = color # Normal Solid Color
  ctx.colorAA = color and 0xFFFFFF # Antialiased

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
  var # Antialiased
    i, j: int32 # Sides
    k, l: int32 = 3 # AA
    x, y, norm: float32
  while i < 3:
    j = (i + 1) mod 3 # Truncate Side
    x = ctx.pVert[i].y - ctx.pVert[j].y
    y = ctx.pVert[j].x - ctx.pVert[i].x
    # Normalize Position Vector
    norm = invSqrt(x*x + y*y)
    x *= norm; y *= norm
    # Add Antialiased Vertexs to Triangle Sides
    ctx.vertexAA(k, ctx.pVert[i].x + x, ctx.pVert[i].y + y)
    ctx.vertexAA(k+1, ctx.pVert[j].x + x, ctx.pVert[j].y + y)
    # Add Antialiased Elements
    ctx.triangle(l, i, j, k)
    ctx.triangle(l+3, j, k, k+1)
    # Next Triangle Size
    i += 1; k += 2; l += 6

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
  # Move X & Y to Center
  unsafeAddr(p.x)[] += r
  unsafeAddr(p.y)[] += r
  let # Angle Constants
    n = int32 5 * fastSqrt(r)
    theta = 2 * PI / float32(n)
  # Circle Triangles and Elements
  ctx.addVerts(n shl 1, n * 9)
  var # Iterator
    o, ox, oy: float32
    i, j, k: int32
  while i < n:
    # Direction Normals
    ox = cos(o); oy = sin(o)
    # Vertex Information
    ctx.vertex(j, # Solid
      p.x + ox * r, 
      p.y + oy * r)
    ctx.vertexAA(j + 1, # AA
      ctx.pVert[j].x + ox,
      ctx.pVert[j].y + oy)
    if i + 1 < n:
      ctx.triangle(k, 0, j, j + 2)
      ctx.triangle(k + 3, j, j + 1, j + 2)
      ctx.triangle(k + 6, j + 1, j + 2, j + 3)
    else: # Connect Last With First
      ctx.triangle(k, 0, j, 0)
      ctx.triangle(k + 3, j, 1, 0)
      ctx.triangle(k + 6, j, j + 1, 1)
    # Next Circle Triangle
    i += 1; j += 2; k += 9
    o += theta; # Next Angle

# ----------------------------
# TEXT & ICONS RENDERING PROCS
# ----------------------------

proc text*(ctx: ptr CTXRender, x,y: int32, str: string) =
  # Offset Y to Atlas Font Y Offset Metric
  unsafeAddr(y)[] += metrics.baseline
  # Render Text Top to Bottom
  for rune in runes16(str):
    let glyph = # Load Glyph
      ctx.atlas.glyph(rune)
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

proc text*(ctx: ptr CTXRender, x,y: int32, clip: CTXRect, str: string) =
  # Offset Y to Atlas Font Y Offset Metric
  unsafeAddr(y)[] += metrics.baseline
  # Render Text Top to Bottom
  for rune in runes16(str):
    let glyph = # Load Glyph
      ctx.atlas.glyph(rune)
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

proc icon*(ctx: ptr CTXRender, x,y: int32, id: uint16) =
  ctx.addVerts(4, 6)
  let # Icon Rect
    x = float32 x
    y = float32 y
    xw = x + float32 metrics.iconSize
    yh = y + float32 metrics.iconSize
    # Lookup Icon from Atlas
    icon = ctx.atlas.icon(id)
  # Icon Vertex Definition
  ctx.vertexUV(0, x, y, icon.x1, icon.y1)
  ctx.vertexUV(1, xw, y, icon.x2, icon.y1)
  ctx.vertexUV(2, x, yh, icon.x1, icon.y2)
  ctx.vertexUV(3, xw, yh, icon.x2, icon.y2)
  # Elements Definition
  ctx.triangle(0, 0,1,2)
  ctx.triangle(3, 1,2,3)
