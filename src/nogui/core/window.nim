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
  GUILayer = object
    first: GUIWidget
    last {.cursor.}: GUIWidget
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
    # Window State
    ctx: CTXRender
    state: GUIState
    queue: GUIQueue
    # Window Widgets
    root: GUIWidget
    # Window Layers
    frame: GUILayer
    popup: GUILayer
    tooltip: GUILayer
    # Status Widgets
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

# ----------------------
# Window Execution Procs
# ----------------------

proc execute*(win: GUIWindow, root: GUIWidget): bool =
  win.root = root
  # Set as Frame Kind
  root.kind = wgRoot
  #root.flags.incl(wVisible)
  root.flags = {wMouse, wKeyboard, wVisible}
  # Set to Global Dimensions
  root.metrics.w = int16 win.w
  root.metrics.h = int16 win.h
  # Shows the Window on the screen
  result = XMapWindow(win.display, win.xID) != BadWindow
  discard XSync(win.display, 0) # Wait for show it
  # Set Renderer Viewport Dimensions
  viewport(win.ctx, win.w, win.h)
  # TODO: defer this callback
  pushSignal(root.target, msgDirty)

proc destroy*(win: GUIWindow) =
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

# ------------------
# Window Layer Procs
# ------------------

proc attach(layer: var GUILayer, widget: GUIWidget) =
  if isNil(layer.last):
    layer.first = widget
    layer.last = widget
    # Remove Endpoints
    widget.next = nil
    widget.prev = nil
    widget.parent = nil
  else: # Attach Last
    attachNext(layer.last, widget)
    layer.last = widget

proc detach(layer: var GUILayer, widget: GUIWidget) =
  # Replace First or Last
  if widget == layer.first:
    layer.first = widget.next
  if widget == layer.last:
    layer.last = widget.prev
  # Detach Widget
  widget.detach()
  # Remove Endpoints
  widget.next = nil
  widget.prev = nil

proc elevate(layer: var GUILayer, widget: GUIWidget) =
  # Nothing to Elevate
  if widget == layer.last:
    return
  # Replace First
  if widget == layer.first:
    layer.first = widget.next
  # Detach Widget
  widget.detach()
  # Attach to Last
  attachNext(layer.last, widget)
  layer.last = widget

# -----------------------------
# Window Layer Open/Close Procs
# -----------------------------

proc layer(win: GUIWindow, widget: GUIWidget): ptr GUILayer =
  case widget.kind
  of wgFrame: addr win.frame
  of wgPopup, wgMenu: addr win.popup
  of wgTooltip: addr win.tooltip
  # Not Belongs to Layer
  else: nil

proc open(win: GUIWindow, widget: GUIWidget) =
  if wVisible in widget.flags: return
  # Attach Widget to Layer
  let la = win.layer(widget)
  la[].attach(widget)
  # Handle Widget Attach
  widget.flags.incl(wVisible)
  widget.vtable.handle(widget, inFrame)
  widget.arrange()
  echo "opened: ", cast[pointer](widget).repr

proc close(win: GUIWindow, widget: GUIWidget) =
  let la = win.layer(widget)
  la[].detach(widget)
  # Handle Widget Detach
  widget.flags.excl(wVisible)
  widget.vtable.handle(widget, outFrame)
  echo "closed: ", cast[pointer](widget).repr

# ---------------------------------
# GUI WINDOW MAIN LOOP HELPER PROCS
# ---------------------------------

# -- Find Widget by State
proc find(win: GUIWindow, state: ptr GUIState): GUIWidget =
  case state.kind
  of evCursorMove, evCursorClick, evCursorRelease:
    if not isNil(win.hover) and wGrab in win.hover.flags:
      result = win.hover
      # Check Grabbed Point On Area
      if pointOnArea(result, state.mx, state.my):
        result.flags.incl(wHover)
      else: result.flags.excl(wHover)
      # Return Widget
      return result
    elif not isNil(win.popup.last):
      # TODO: event propagation to just lookup first popup for menus
      for widget in reverse(win.popup.last):
        if widget.kind == wgPopup or pointOnArea(widget, state.mx, state.my):
          result = widget
          break # Popup Found
    elif not isNil(win.frame.last): # Find Frames
      for widget in reverse(win.frame.last):
        if pointOnArea(widget, state.mx, state.my):
          result = widget
          break # Frame Found
    # Fallback to Root
    else: result = win.root
    # Check if Not Found
    if isNil(result):
      if not isNil(win.hover):
        handle(win.hover, outHover)
        excl(win.hover.flags, wHover)
        # Remove Hover
        win.hover = nil
    # Check if is Outside of a Popup
    elif result.kind == wgPopup and
    not pointOnArea(result, state.mx, state.my):
      # Remove Hover Flag
      result.flags.excl(wHover)
    # Check if is at the same frame
    elif not isNil(win.hover) and 
    result == win.hover.outside:
      result = # Find Interior Widget
        find(win.hover, state.mx, state.my)
      # Set Hovered Flag
      result.flags.incl(wHover)
    else: # Not at the same frame
      result = # Find Interior Widget
        find(result, state.mx, state.my)
      # Set Hovered Flag
      result.flags.incl(wHover)
    # Check if is not the same
    if result != win.hover:
      # Handle Hover Out
      if not isNil(win.hover):
        handle(win.hover, outHover)
        excl(win.hover.flags, wHover)
      # Handle Hover In
      result.handle(inHover)
      # Replace Hover
      win.hover = result
  of evKeyDown, evKeyUp:
    result = # Focus Root if there is no popup
      if isNil(win.focus) and isNil(win.popup.first):
        win.root # Fallback
      else: win.focus # Use Focus

# -- Prepare Widget before event
proc prepare(win: GUIWindow, widget: GUIWidget, kind: GUIEvent): bool =
  case kind
  of evCursorMove:
    wMouse in widget.flags
  of evCursorClick:
    # Grab Current Widget
    widget.flags.incl(wGrab)
    # Elevate if is a Frame
    let frame = widget.outside
    if frame.kind == wgFrame:
      elevate(win.frame, frame)
    # Check if is able
    wMouse in widget.flags
  of evCursorRelease:
    # Ungrab Current Widget
    widget.flags.excl(wGrab)
    # Check if is able
    wMouse in widget.flags
  of evKeyDown, evKeyUp:
    wKeyboard in widget.flags

# -- Step Focus
proc step(win: GUIWindow, back: bool) =
  var widget = win.focus
  if not isNil(widget.parent):
    widget = step(widget, back)
    if widget != win.focus:
      # Handle Focus Out
      excl(win.focus.flags, wFocus)
      handle(win.focus, outFocus)
      # Handle Focus In
      widget.flags.incl(wFocus)
      widget.handle(inFocus)
      # Change Focus
      win.focus = widget

proc check(win: GUIWindow, widget: GUIWidget) =
  # Check if is still focused
  if widget == win.focus and
  wFocusable + {wFocus} notin widget.flags:
    widget.flags.excl(wFocus)
    widget.handle(outFocus)
    # Remove Focus
    win.focus = nil

# -- Focus Handling
proc focus(win: GUIWindow, widget: GUIWidget) =
  if widget != win.root and
  wFocusable in widget.flags and
  widget != win.focus:
    if not isNil(win.focus):
      excl(win.focus.flags, wFocus)
      handle(win.focus, outFocus)
    # Handle Focus In
    widget.flags.incl(wFocus)
    widget.handle(inFocus)
    # Replace Focus
    win.focus = widget

# -- Relayout Widget, TODO: change dirty naming
proc dirty(win: GUIWindow, widget: GUIWidget) =
  if wVisible in widget.flags:
    # Arrange Widget and Check Focus
    widget.arrange()
    win.check(widget)

# ------------------------
# GUI EVENT HANDLING PROCS
# ------------------------

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
        # TODO: defer this callback
        pushSignal(win.root.target, msgDirty)
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
      # Window Layer Widget
      of msgOpen: open(win, widget)
      of msgClose: close(win, widget)
    of sWindow:
      case signal.wsg
      of msgOpenIM: XSetICFocus(win.xic)
      of msgCloseIM: XUnsetICFocus(win.xic)
      of msgUnfocus: # Un Focus
        if not isNil(win.focus):
          excl(win.focus.flags, wFocus)
          handle(win.focus, outFocus)
          # Remove Focus
          win.focus = nil
      of msgUnhover: # Un Hover
        if not isNil(win.hover):
          handle(win.hover, outHover)
          excl(win.hover.flags, wHoverGrab)
          # Remove Hover
          win.hover = nil
      of msgTerminate: 
        return true

proc handleTimers*(win: GUIWindow) =
  for widget in walkTimers():
    widget.update()

# -------------------
# GUI RENDERING PROCS
# -------------------

proc renderLayer(ctx: ptr CTXRender, layer: GUILayer) =
  if isNil(layer.first): return
  # Render Widgets
  for w in forward(layer.first):
    w.render(ctx)
    ctx[].render()

proc render*(win: GUIWindow) =
  begin(win.ctx) # -- Begin GUI Rendering
  let ctx = addr win.ctx
  # Render Root
  render(win.root, ctx)
  ctx[].render()
  # Render Window Layers
  ctx.renderLayer(win.frame)
  ctx.renderLayer(win.popup)
  ctx.renderLayer(win.tooltip)
  finish() # -- End GUI Rendering
  # Present Frame to EGL
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
