import ../logger
# Import Libraries
import ../libs/egl
import x11/xlib, x11/x
# Import Modules
from atlas import CTXAtlas, createTexture
import widget, event, signal, render
# Import Somes
from timer import walkTimers
from ../libs/gl import gladLoadGL
# TODO: Split EGL and native platform from window

let
  # NPainter EGL Configurations
  attEGL = [
    # Color Channels
    EGL_RED_SIZE, 8,
    EGL_GREEN_SIZE, 8,
    EGL_BLUE_SIZE, 8,
    # Render Type
    EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
    EGL_NONE
  ]
  attCTX = [
    EGL_CONTEXT_MAJOR_VERSION, 3,
    EGL_CONTEXT_MINOR_VERSION, 3,
    EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
    EGL_NONE
  ]
  attSUR = [
    EGL_RENDER_BUFFER, EGL_BACK_BUFFER,
    EGL_NONE
  ]

type
  GUIWindow* = ref object
    # X11 Display & Window
    display: PDisplay
    xID: Window
    w*, h*: int32
    # X11 Cursor
    xCursor: Cursor
    xCursorLabel: Cursor
    # X11 Input Method
    xim: XIM
    xic: XIC
    # EGL Context
    eglDsp: EGLDisplay
    eglCfg: EGLConfig
    eglCtx: EGLContext
    eglSur: EGLSurface
    # Main Window
    ctx: CTXRender
    state: GUIState
    queue: GUIQueue
    # Root Widget
    root: GUIWidget
    # Last Widgets
    frame: GUIWidget
    popup: GUIWidget
    tooltip: GUIWidget
    # Cache Widgets
    focus: GUIWidget
    hover: GUIWidget

const LC_ALL = 6 # Hardcopied from gcc header
proc setlocale(category: cint, locale: cstring): cstring
  {.cdecl, importc, header: "<locale.h>".}

# -----------------------------
# X11/EGL WINDOW CREATION PROCS
# -----------------------------

proc createXIM(win: GUIWindow) =
  if setlocale(LC_ALL, "").isNil or XSetLocaleModifiers("").isNil:
    log(lvWarning, "proper C locale not found")
  # Try Create Default Input Method or use Fallback
  win.xim = XOpenIM(win.display, nil, nil, nil)
  if win.xim == nil:
    discard XSetLocaleModifiers("@im=none")
    win.xim = XOpenIM(win.display, nil, nil, nil)
  # Create Input Context
  win.xic = XCreateIC(win.xim, XNInputStyle, XIMPreeditNothing or
      XIMStatusNothing, XNClientWindow, win.xID, nil)
  if win.xic == nil:
    log(lvWarning, "failed creating XIM context")

proc createXWindow(x11: PDisplay, w, h: uint32): Window =
  var # Attributes and EGL
    attr: XSetWindowAttributes
  attr.event_mask =
    KeyPressMask or
    KeyReleaseMask or
    StructureNotifyMask
  # Get Default Root Window From Display
  let root = DefaultRootWindow(x11)
  # -- Create X11 Window With Default Flags
  result = XCreateWindow(x11, root, 0, 0, w, h, 0, 
    CopyFromParent, CopyFromParent, nil, CWEventMask, addr attr)
  if result == 0: # Check if Window was created properly
    log(lvError, "failed creating X11 window")

proc createEGL(win: GUIWindow) =
  var
    # New EGL Instance
    eglDsp: EGLDisplay
    eglCfg: EGLConfig
    eglCtx: EGLContext
    eglSur: EGLSurface
    # Checks
    ignore: EGLint
    cfgNum: EGLint
    ok: EGLBoolean
  # Bind OpenGL API
  ok = eglBindAPI(EGL_OPENGL_API)
  # Get EGL Display from X11 Display
  eglDsp = eglGetDisplay(win.display)
  # Initialize EGL
  ok = ok and eglInitialize(eglDsp, ignore.addr, ignore.addr)
  # Choose EGL Configuration for Standard OpenGL
  ok = ok and eglChooseConfig(eglDsp, 
    cast[ptr EGLint](attEGL.unsafeAddr),
    eglCfg.addr, 1, cfgNum.addr) and cfgNum != 0
  # Create Context and Window Surface
  eglCtx = eglCreateContext(eglDsp, eglCfg, EGL_NO_CONTEXT, 
    cast[ptr EGLint](attCTX.unsafeAddr))
  # Check if EGL Context was created properly
  if not ok or eglDsp.pointer.isNil or 
      eglCfg.pointer.isNil or eglCtx.pointer.isNil:
    log(lvError, "failed creating EGL context"); return
  # Create EGL Surface and make it current
  eglSur = eglCreateWindowSurface(eglDsp, eglCfg, 
    win.xID, cast[ptr EGLint](attSUR.unsafeAddr))
  if eglSur.pointer.isNil or not # Check if was created properly
      eglMakeCurrent(eglDsp, eglSur, eglSur, eglCtx):
    log(lvError, "failed creating EGL surface"); return
  # -- Load GL functions and check it
  if not gladLoadGL(eglGetProcAddress):
    log(lvError, "failed loading GL functions"); return
  # Save new EGL Context
  win.eglDsp = eglDsp
  win.eglCfg = eglCfg
  win.eglCtx = eglCtx
  win.eglSur = eglSur

proc newGUIWindow*(w, h: int32, queue: GUIQueue, atlas: CTXAtlas): GUIWindow =
  new result
  # Create new X11 Display
  result.display = XOpenDisplay(nil)
  if isNil(result.display):
    log(lvError, "failed opening X11 display")
  # Create a X11 Window
  result.xID = createXWindow(result.display, uint32 w, uint32 h)
  # Set Current Dimensions
  result.w = w
  result.h = h
  # Create X11 Input Method
  result.createXIM()
  # Create GUI Event State
  result.state = newGUIState(
    result.display, result.xID)
  # Create EGL Context
  result.createEGL() # Disable VSync
  discard eglSwapInterval(result.eglDsp, 0)
  # Set Current Queue
  result.queue = queue
  # Create CTX Renderer
  atlas.createTexture()
  result.ctx = newCTXRender(atlas)

# -----------------------
# WINDOW OPEN/CLOSE PROCS
# -----------------------

proc open*(win: GUIWindow, root: GUIWidget): bool =
  # Set First Widget and Last Frame
  win.root = root; win.frame = root
  # Set as Frame Kind
  root.kind = wgFrame
  root.flags.set(wVisible)
  # Set to Global Dimensions
  root.metrics.w = int16 win.w
  root.metrics.h = int16 win.h
  # Shows the Window on the screen
  result = XMapWindow(win.display, win.xID) != BadWindow
  discard XSync(win.display, 0) # Wait for show it
  # Set Renderer Viewport Dimensions
  viewport(win.ctx, win.w, win.h)
  # Mark root as Dirty
  set(win.root, wDirty)

proc close*(win: GUIWindow) =
  # Dispose UTF8Buffer
  dealloc(win.state.utf8str)
  # Dispose EGL
  discard eglDestroySurface(win.eglDsp, win.eglSur)
  discard eglDestroyContext(win.eglDsp, win.eglCtx)
  discard eglTerminate(win.eglDsp)
  # Dispose all X Stuff
  XDestroyIC(win.xic)
  discard XCloseIM(win.xim)
  discard XDestroyWindow(win.display, win.xID)
  discard XCloseDisplay(win.display)

# -----------------------------
# WINDOW FLOATING PRIVATE PROCS
# -----------------------------

# -- Add Helper
proc insert(pivot, widget: GUIWidget) =
  # Add to left of widget next
  widget.next = pivot.next
  if not isNil(pivot.next):
    pivot.next.prev = widget
  # Add to right of widget
  widget.prev = pivot
  pivot.next = widget

# -- Delete Helper
proc delete(widget: GUIWidget) =
  # Check if next is not nil
  if not isNil(widget.next):
    widget.next.prev = widget.prev
  # Prev Widget is allways not nil
  widget.prev.next = widget.next
  # Remove next and prev
  widget.next = nil
  widget.prev = nil

# --- Mark As Top Level ---
proc elevate(win: GUIWindow, widget: GUIWidget) =
  if widget != win.root and widget != win.frame:
    # Remove frame from it's position
    widget.prev.next = widget.next
    widget.next.prev = widget.prev
    # Move frame to last frame
    widget.prev = win.frame
    widget.next = win.frame.next
    # Change Prev Last Next
    if not isNil(widget.next):
      widget.next.prev = widget
    # Change Last Frame
    win.frame.next = widget
    win.frame = widget

# ---------------------------------
# GUI WINDOW MAIN LOOP HELPER PROCS
# ---------------------------------

# -- Find Widget by State
proc find(win: GUIWindow, state: ptr GUIState): GUIWidget =
  case state.kind
  of evCursorMove, evCursorClick, evCursorRelease:
    if not isNil(win.hover) and test(win.hover, wGrab):
      result = win.hover
      # Check Grabbed Point On Area
      if pointOnArea(result, state.mx, state.my):
        result.flags.set(wHover)
      else: result.flags.clear(wHover)
      # Return Widget
      return result
    elif isNil(win.popup): # Find Frames
      for widget in reverse(win.frame):
        if pointOnArea(widget, state.mx, state.my):
          result = widget; break # Frame Found
    else: # TODO: event propagation
      for widget in reverse(win.popup):
        if widget == win.frame: break # Not Found
        if widget.kind == wgPopup or pointOnArea(
            widget, state.mx, state.my):
          result = widget; break # Popup Found
    # Check if Not Found
    if isNil(result):
      if not isNil(win.hover):
        handle(win.hover, outHover)
        clear(win.hover.flags, wHover)
        # Remove Hover
        win.hover = nil
    # Check if is Outside of a Popup
    elif result.kind == wgPopup and
    not pointOnArea(result, state.mx, state.my):
      # Remove Hover Flag
      result.flags.clear(wHover)
    # Check if is at the same frame
    elif not isNil(win.hover) and 
    result == win.hover.outside:
      result = # Find Interior Widget
        find(win.hover, state.mx, state.my)
      # Set Hovered Flag
      result.flags.set(wHover)
    else: # Not at the same frame
      result = # Find Interior Widget
        find(result, state.mx, state.my)
      # Set Hovered Flag
      result.flags.set(wHover)
    # Check if is not the same
    if result != win.hover:
      # Handle Hover Out
      if not isNil(win.hover):
        handle(win.hover, outHover)
        clear(win.hover.flags, wHover)
      # Handle Hover In
      result.handle(inHover)
      # Replace Hover
      win.hover = result
  of evKeyDown, evKeyUp:
    result = # Focus Root if there is no popup
      if isNil(win.focus) and isNil(win.popup):
        win.root # Fallback
      else: win.focus # Use Focus

# -- Prepare Widget before event
proc prepare(win: GUIWindow, widget: GUIWidget, kind: GUIEvent): bool =
  case kind
  of evCursorMove:
    widget.test(wMouse)
  of evCursorClick:
    # Grab Current Widget
    widget.flags.set(wGrab)
    # Elevate if is a Frame
    let frame = widget.outside
    if frame.kind == wgFrame:
      elevate(win, frame)
    # Check if is able
    widget.test(wMouse)
  of evCursorRelease:
    # Ungrab Current Widget
    widget.flags.clear(wGrab)
    # Check if is able
    widget.test(wMouse)
  of evKeyDown, evKeyUp:
    widget.test(wKeyboard)

# -- Step Focus
proc step(win: GUIWindow, back: bool) =
  var widget = win.focus
  if not isNil(widget.parent):
    widget = step(widget, back)
    if widget != win.focus:
      # Handle Focus Out
      clear(win.focus.flags, wFocus)
      handle(win.focus, outFocus)
      # Handle Focus In
      widget.flags.set(wFocus)
      widget.handle(inFocus)
      # Change Focus
      win.focus = widget

# -- Relayout Widget, TODO: change dirty
proc dirty(win: GUIWindow, widget: GUIWidget) =
  if widget.test(wVisible):
    widget.arrange()
    # Check Focus Visibility
    if not isNil(win.focus) and 
    not win.focus.visible:
      clear(win.focus.flags, wFocus)
      handle(win.focus, outFocus)
      # Remove Focus
      win.focus = nil
  widget.flags.clear(wDirty)

# -- Focus Handling
proc focus(win: GUIWindow, widget: GUIWidget) =
  if widget != win.root and
  widget.test(wFocusCheck) and
  widget != win.focus:
    if not isNil(win.focus):
      clear(win.focus.flags, wFocus)
      handle(win.focus, outFocus)
    # Handle Focus In
    widget.flags.set(wFocus)
    widget.handle(inFocus)
    # Replace Focus
    win.focus = widget

proc check(win: GUIWindow, widget: GUIWidget) =
  # Check if is still focused
  if widget == win.focus and
  not widget.test(wFocusCheck or wFocus):
    widget.flags.clear(wFocus)
    widget.handle(outFocus)
    # Remove Focus
    win.focus = nil

# -- Close any Frame/Popup/Tooltip
proc close(win: GUIWindow, widget: GUIWidget) =
  if widget.test(wVisible) and
  widget.kind > wgChild and
  widget != win.root: # Avoid Root
    # is Last Frame?
    if widget == win.frame:
      win.frame = widget.prev
    # is Last Popup?
    elif widget == win.popup:
      let prev = widget.prev
      # No more popups?
      if prev == win.frame:
        win.popup = nil
      else: win.popup = prev
    # is Last Tooltip?
    elif widget == win.tooltip:
      let prev = widget.prev
      # No more tooltips?
      if prev == win.popup or
         prev == win.frame:
        win.tooltip = nil
      else: win.tooltip = prev
    # Remove from List
    widget.delete()
    # Remove Visible Flag
    widget.flags.clear(wVisible)
    # Unfocus Children Widget
    if not isNil(win.focus) and
    win.focus.outside == widget:
      clear(win.focus.flags, wFocus)
      handle(win.focus, outFocus)
      # Remove Focus
      win.focus = nil
    # Unhover Children Widget
    if not isNil(win.hover) and
    win.hover.outside == widget:
      handle(win.hover, outHover)
      clear(win.hover.flags, wHoverGrab)
      # Remove Hover
      win.hover = nil
    # Handle outFrame
    widget.handle(outFrame)

# -- Open as Frame/Popup/Tooltip
proc frame(win: GUIWindow, widget: GUIWidget) =
  if widget.kind > wgChild and
  not widget.test(wVisible):
    insert(win.frame, widget)
    win.frame = widget
    # Remove Parent if has
    widget.parent = nil
    # Mark as Visible and Dirty
    widget.flags.set(wVisible)
    widget.set(wDirty)

proc popup(win: GUIWindow, widget: GUIWidget) =
  if widget.kind > wgChild and
  not widget.test(wVisible):
    # Insert Widget to List
    if isNil(win.popup):
      insert(win.frame, widget)
    else: # Change Last Popup
      insert(win.popup, widget)
    # Change Last Popup
    win.popup = widget
    # Remove Parent if has
    widget.parent = nil
    # Mark as Visible and Dirty
    widget.flags.set(wVisible)
    widget.set(wDirty)

proc tooltip(win: GUIWindow, widget: GUIWidget) =
  if widget.kind > wgChild and
  not widget.test(wVisible):
    # Inset Widget To List
    if not isNil(win.tooltip):
      insert(win.tooltip, widget)
    elif not isNil(win.popup):
      insert(win.popup, widget)
    else: # Insert at Frame
      insert(win.frame, widget)
    # Change Last Tooltip
    win.tooltip = widget
    # Remove Parent if has
    widget.parent = nil
    # Mark as Visible and Dirty
    widget.flags.set(wVisible)
    widget.set(wDirty)

# --------------------------
# GUI WINDOW MAIN LOOP PROCS
# --------------------------

proc handleEvents*(win: GUIWindow) =
  var event: XEvent
  # Input Event Handing
  while XPending(win.display) != 0:
    discard XNextEvent(win.display, addr event)
    if XFilterEvent(addr event, 0) != 0:
      continue # Skip IM Event
    case event.theType:
    of Expose: discard
    of ConfigureNotify: # Resize
      let 
        rect = addr win.root.metrics
        config = addr event.xconfigure
      if config.window == win.xID and
          (config.width != rect.w or
          config.height != rect.h):
        rect.w = int16 config.width
        rect.h = int16 config.height
        # Set Window Metrics
        win.w = rect.w
        win.h = rect.h
        # Set Renderer Viewport
        viewport(win.ctx, rect.w, rect.h)
        # Relayout Root Widget
        set(win.root, wDirty)
    else: # Check if the event is valid for be processed by a widget
      if translateXEvent(win.state, win.display, addr event, win.xic):
        let # Avoids win.state everywhere
          state = addr win.state
          tabbed = state.kind == evKeyDown and
            (state.key == RightTab or state.key == LeftTab)
        # Find Widget for Process Event
        if tabbed and not isNil(win.focus):
          step(win, state.key == LeftTab)
        else: # Process Event
          let found = find(win, state)
          # Check if can handle
          if not isNil(found) and
          win.prepare(found, state.kind):
            event(found, state)

proc handleSignals*(win: GUIWindow): bool =
  for signal in poll(win.queue):
    case signal.kind
    of sCallback, sCallbackEX:
      signal.call()
    of sWidget:
      let widget =
        cast[GUIWidget](signal.id)
      case signal.msg
      of msgDirty: dirty(win, widget)
      of msgFocus: focus(win, widget)
      of msgCheck: check(win, widget)
      of msgClose: close(win, widget)
      of msgFrame: frame(win, widget)
      of msgPopup: popup(win, widget)
      of msgTooltip: tooltip(win, widget)
    of sWindow:
      case signal.wsg
      of msgOpenIM: XSetICFocus(win.xic)
      of msgCloseIM: XUnsetICFocus(win.xic)
      of msgUnfocus: # Un Focus
        if not isNil(win.focus):
          clear(win.focus.flags, wFocus)
          handle(win.focus, outFocus)
          # Remove Focus
          win.focus = nil
      of msgUnhover: # Un Hover
        if not isNil(win.hover):
          handle(win.hover, outHover)
          clear(win.hover.flags, wHoverGrab)
          # Remove Hover
          win.hover = nil
      of msgTerminate: 
        return true

proc handleTimers*(win: GUIWindow) =
  for widget in walkTimers():
    widget.update()

proc render*(win: GUIWindow) =
  begin(win.ctx) # -- Begin GUI Rendering
  for widget in forward(win.root):
    widget.draw(addr win.ctx)
    # Render Widget Childrens
    if not isNil(widget.first):
      render(widget, addr win.ctx)
    # Draw Commands
    render(win.ctx)
  finish() # -- End GUI Rendering
  # Present Frame to X11/EGL
  discard eglSwapBuffers(win.eglDsp, win.eglSur)

# -----------------------------------------------
# TODO: Get rid of this with native plaforms on C
# -----------------------------------------------
export x.Cursor
# Import Xcursor.h missing
include x11/x11pragma
const libXcursor* = "libXcursor.so"
{.pragma: libXcursor, cdecl, dynlib: libXcursor, importc.}
proc XcursorLibraryLoadCursor(dpy: PDisplay, name: cstring): Cursor {.libXcursor.}

proc freeCursor(win: GUIWindow) =
  let cursor = win.xCursor
  # Free Cursor if is not Custom
  if win.xCursorLabel > 0 and cursor > 0:
    discard XFreeCursor(win.display, cursor)
  # Free Current Cursor
  win.xCursor = 0
  win.xCursorLabel = 0

proc clearCursor*(win: GUIWindow) =
  if XUndefineCursor(win.display, win.xID) > 1:
   log(lvWarning, "failed restoring cursor")
  # Free Cursor
  win.freeCursor()

template setCursor(win: GUIWindow, cursor: Cursor) =
  let display = win.display
  # Clear Cursor First
  win.freeCursor()
  # Change Window Cursor
  if XDefineCursor(display, win.xID, cursor) > 1:
    log(lvWarning, "failed loading cursor")
  # Set Current Cursor Handle
  win.xCursor = cursor
  win.xCursorLabel = cursor

proc setCursor*(win: GUIWindow, code: int) =
  let found = XCreateFontCursor(win.display, cuint code)
  win.setCursor(found)

proc setCursor*(win: GUIWindow, name: cstring) =
  let found = XcursorLibraryLoadCursor(win.display, name)
  win.setCursor(found)

proc setCursorCustom*(win: GUIWindow, custom: Cursor) =
  let display = win.display
  # Clear Cursor First
  win.freeCursor()
  # Change Window Cursor
  if XDefineCursor(display, win.xID, custom) > 1:
    log(lvWarning, "failed loading cursor")
  # Set Current Cursor Handle
  win.xCursor = custom
