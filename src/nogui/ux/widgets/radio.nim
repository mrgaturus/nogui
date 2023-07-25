import ../widget, ../render
from ../event import 
  GUIState, GUIEvent
from ../config import 
  metrics, theme
from ../../builder import widget

widget GUIRadio:
  attributes:
    label: string
    expected: byte
    check: ptr byte

  new radio(label: string, expected: byte, check: ptr byte):
    # Set to Font Size Metrics
    result.minimum(0, metrics.fontSize)
    # Widget Standard Flag
    result.flags = wMouse
    # Radio Button Attributes
    result.label = label
    result.expected = expected
    result.check = check

  method draw(ctx: ptr CTXRender) =
    ctx.color: # Select Color State
      if not self.any(wHoverGrab):
        theme.bgWidget
      elif self.test(wHoverGrab):
        theme.grabWidget
      else: theme.hoverWidget
    # Fill Radio Background
    ctx.circle point(
      self.rect.x, self.rect.y),
      float32(self.rect.h shr 1)
    # If Checked Draw Circle Mark
    if self.check[] == self.expected:
      ctx.color(theme.mark)
      ctx.circle point(
        self.rect.x + 4, self.rect.y + 4),
        float32(self.rect.h shr 1 - 4)
    # Draw Text Next To Circle
    ctx.color(theme.text)
    ctx.text( # Centered Vertically
      self.rect.x + self.rect.h + 4, 
      self.rect.y - metrics.descender,
      self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and self.test(wHover):
      self.check[] = self.expected
