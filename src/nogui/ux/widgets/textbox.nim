import ../prelude
# --------------------
from x11/keysym import
  XK_Backspace, XK_Left, XK_Right,
  XK_Return, XK_Escape,
  XK_Delete, XK_Home, XK_End
import x11/cursorfont
from ../../../nogui import 
  setCursor, clearCursor
# -----------------------
import ../../utf8
from ../../gui/event import 
  UTF8Nothing, UTF8Keysym
from ../../gui/signal import 
  WindowSignal, msgOpenIM, msgCloseIM

widget UXTextBox:
  attributes:
    input: ptr UTF8Input
    # Text Metric Cache
    [wc, wo, wl]: int32

  new textbox(input: ptr UTF8Input):
    result.flags = wMouse or wKeyboard
    # Widget Attributes
    result.input = input

  method update =
    let 
      font = addr getApp().font
      size = font.height - font.desc
    # Set Minimun Size
    self.minimum(size, size)

  proc calculateOffsets() =
    let
      size = getApp().font.size
      input = self.input
      # Text Sizes
      wr = self.rect.w - size
      wc = width(input.text, input.index)
    # Prev Offset
    var wo = self.wo
    # Check Offset Change
    if wc < wo:
      wo -= wo - wc
    elif wc > wo + wr:
      wo += wc - wo - wr
    # Change Cursor Offset
    self.wc = wc
    self.wo = wo
    # Caret Offset Cache
    self.wl = wc - wo

  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      rect = addr self.rect
      metrics = addr app.font
      colors = addr app.colors
      # Text Input
      size = metrics.size shr 1
      input = self.input
    # Reset Cursor and Offset Cache
    if not input.check cast[pointer](self):
      self.wc = 0; self.wo = 0; self.wl = 0
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
          rect.x + self.wl + size,
          rect.y - metrics.desc,
          1, metrics.asc)
      else: # Hover Outline Color
        ctx.color(colors.focus)
      # Draw Outline Status
      ctx.line rect(self.rect), 1
    # Set Color To White
    ctx.color(colors.text)
    # Draw Current Text
    ctx.text( # Offset X and Clip
      rect.x - self.wo + size,
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
    elif self.test(wGrab):
      input.focus cast[pointer](self)
      # Jump to Cursor Position
      let size = getApp().font.size shr 1
      input.jump index(input.text, 
        state.mx - self.rect.x - size + self.wo)
      # Focus Textbox
      if state.kind == evCursorClick:
        self.set(wFocus)
    # Mark Text Input used By This Widget
    if state.kind in {evKeyDown, evCursorClick, evCursorMove}:
      self.calculateOffsets()

  method handle(kind: GUIHandle) =
    # Prepare Input Focus
    case kind 
    of inFocus:
      # Change Current Widget
      self.input.focus cast[pointer](self)
      pushSignal(msgOpenIM)
    of outFocus: 
      pushSignal(msgCloseIM)
    of inHover:
      getApp().setCursor(XC_xterm)
    of outHover:
      getApp().clearCursor()
    else: discard
