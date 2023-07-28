import ../prelude
# --------------------
from x11/keysym import
  XK_Backspace, XK_Left, XK_Right,
  XK_Return, XK_Escape,
  XK_Delete, XK_Home, XK_End
# -----------------------
import ../../utf8
from ../../gui/event import 
  UTF8Nothing, UTF8Keysym
from ../../gui/signal import 
  WindowSignal, msgOpenIM, msgCloseIM

widget GUITextBox:
  attributes:
    input: ptr UTF8Input
    [wi, wo]: int32

  new textbox(input: ptr UTF8Input):
    let metrics = addr getApp().font
    # Widget Standard Flags
    result.flags = wMouse or wKeyboard
    # Set Minimun Size Like a Button
    result.minimum(0, 
      metrics.height - metrics.desc)
    # Widget Attributes
    result.input = input

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      metrics = addr app.font
      colors = addr app.colors
      input = self.input
    # Recalculate Text Scroll and Cursor
    if true: 
      self.wi = width(self.input.text, input.index)
      if self.wi - self.wo > rect.w - 8: # Multiple of 24
        self.wo = (self.wi - rect.w + 32) div 24 * 24
      elif self.wi < self.wo: # Multiple of 24
        self.wo = self.wi div 24 * 24
      self.wi -= self.wo
    # Fill TextBox Background
    ctx.color(colors.darker)
    ctx.fill rect(self.rect)
    # Draw Textbox Status
    if self.any(wHover or wFocus):
      if self.test(wFocus):
        # Focused Outline Color
        ctx.color(colors.text)
        # Draw Cursor
        ctx.fill rect(
          rect.x + self.wi + 4,
          rect.y - metrics.desc,
          1, metrics.asc)
      else: # Hover Outline Color
        ctx.color(colors.focus)
      # Draw Outline Status
      ctx.line rect(self.rect), -1
    # Set Color To White
    ctx.color(colors.text)
    # Draw Current Text
    ctx.text( # Offset X and Clip
      rect.x - self.wo + 4,
      rect.y + metrics.asc shr 1,
      rect(self.rect), input.text)

  method event(state: ptr GUIState) =
    let input = self.input
    if state.kind == evKeyDown:
      case state.key
      of XK_BackSpace: input.backspace()
      of XK_Delete: input.delete()
      of XK_Right: input.next()
      of XK_Left: input.prev()
      of XK_Home: input.jump(low int32)
      of XK_End: input.jump(high int32)
      of XK_Return, XK_Escape: 
        self.clear(wFocus)
      else: # Add UTF8 Char
        case state.utf8state
        of UTF8Nothing, UTF8Keysym: discard
        else: input.insert(state.utf8str, state.utf8size)
    elif state.kind == evCursorClick:
      # Jump to Cursor Position
      input.jump index(input.text, 
        state.mx - self.rect.x + self.wo - 4)
      # Focus Textbox
      self.set(wFocus)
    # Mark Text Input used By This Widget
    if state.kind in {evKeyDown, evCursorClick}:
      input.current cast[pointer](self)

  method handle(kind: GUIHandle) =
    case kind # Un/Focus X11 Input Method
    of inFocus: pushSignal(msgOpenIM)
    of outFocus: pushSignal(msgCloseIM)
    else: discard
