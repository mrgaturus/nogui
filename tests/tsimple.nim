import nogui/libs/gl
import nogui/ux/prelude
import nogui, random

proc rgba0*(r, g, b, a: uint32): CTXColor =
  result = r or (g shl 8) or (b shl 16) or (a shl 24)

# ---------------
# Main GUI Widget
# ---------------

type
  UXBackgroundColor = object
    r, g, b: uint32

proc nextColor(color: var UXBackgroundColor) =
  color.r = uint32 rand(255)
  color.g = uint32 rand(255)
  color.b = uint32 rand(255)

proc mixColor(color0, color1: UXBackgroundColor, t: uint32): CTXColor =
  var color = default(UXBackgroundColor)
  color.r = color0.r + ((color1.r - color0.r) * t) shr 8
  color.g = color0.g + ((color1.g - color0.g) * t) shr 8
  color.b = color0.b + ((color1.b - color0.b) * t) shr 8
  rgba0(color.r, color.g, color.b, 255)

widget UXBackground:
  attributes:
    color0: UXBackgroundColor
    color1: UXBackgroundColor
    step: uint32

  proc nextColor() =
    self.color0 = self.color1
    nextColor(self.color1)
    self.step = 0

  proc nextStep(): CTXColor =
    if self.step > 256:
      self.nextColor()
    # Calculate Interpolation
    result = mixColor(
      self.color0, self.color1, self.step)
    self.step += 2

  new background():
    result.nextColor()

  method draw(ctx: ptr CTXRender) =
    let rect = rect(self.rect)
    ctx.color self.nextStep()
    ctx.fill(rect)
    getWindow().fuse()

# -------------
# Main GUI Proc
# -------------

proc main() =
  createApp(1024, 600)
  let test = background()
  # Open Window
  executeApp(test):
    glClearColor(0.75, 0.75, 0.75, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

when isMainModule:
  main()
