import ../widget, ../render
from ../event import 
  GUIState, GUIEvent
from ../signal import 
  GUICallback, pushCallback
from ../config import metrics, theme
from ../atlas import width
from ../../builder import widget

widget GUIButton:
  attributes:
    cb: GUICallback
    label: string

  new button(label: string, cb: GUICallback):
    # Set to Font Size Metrics
    result.minimum(label.width, 
      metrics.fontSize - metrics.descender)
    # Widget Standard Flag
    result.flags = wMouse
    # Widget Attributes
    result.label = label
    result.cb = cb

  method draw(ctx: ptr CTXRender) =
    ctx.color: # Select Color State
      if not self.any(wHoverGrab):
        theme.bgButton
      elif self.test(wHoverGrab):
        theme.grabButton
      else: theme.hoverButton
    # Fill Button Background
    ctx.fill rect(self.rect)
    # Put Centered Text
    ctx.color(theme.text)
    ctx.text( # Draw Centered Text
      self.rect.x + (self.rect.w - self.hint.w) shr 1, 
      self.rect.y + metrics.ascender shr 1, self.label)

  method event(state: ptr GUIState) =
    if state.kind == evCursorRelease and 
    self.test(wHover) and not isNil(self.cb): 
      pushCallback(self.cb) # Call Callback
