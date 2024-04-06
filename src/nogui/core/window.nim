import ../logger
# Import Libraries
import ../libs/egl
import x11/xlib, x11/x
# Import Modules
from atlas import CTXAtlas, createTexture
import widget, event, signal, render
# Import OpenGL Loader
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
  send(root.target, wsLayout)

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

# --------------------------
# Window Layer Attach/Detach
# --------------------------

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

# -----------------------
# Window Layer Open/Close
# -----------------------

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

proc close(win: GUIWindow, widget: GUIWidget) =
  let la = win.layer(widget)
  la[].detach(widget)
  # Handle Widget Detach
  widget.flags.excl(wVisible)
  widget.vtable.handle(widget, outFrame)

# ---------------------------
# Window Keyboard Event Procs
# ---------------------------

proc findFocus(win: GUIWindow, state: ptr GUIState): GUIWidget =
  let
    focus {.cursor.} = win.focus
    # Check Tab Key Pressed
    tab = state.key == RightTab
    back = state.key == LeftTab
    check = state.kind == evKeyDown and (tab or back)
  # TODO: Check focus step in state translation
  # Check Focus Step Key Pressed
  if not check or isNil(focus):
    return focus
  # Step Focus Widget
  var widget {.cursor.} = focus
  if not isNil(widget.parent):
    widget = step(widget, back)
    if widget != focus:
      # Handle Focus Out
      focus.flags.excl(wFocus)
      focus.vtable.handle(focus, outFocus)
      # Handle Focus In
      widget.flags.incl(wFocus)
      widget.vtable.handle(widget, inFocus)
      # Change Focus
      win.focus = widget

# -------------------------
# Window Cursor Event Procs
# -------------------------

proc findHover(win: GUIWindow, state: ptr GUIState): GUIWidget =
  if not isNil(win.hover) and wGrab in win.hover.flags:
    return win.hover
  # Find Last Popup
  elif not isNil(win.popup.last):
    # TODO: event propagation to make implementation better for menus
    result = win.popup.last
  # Find Frames
  elif not isNil(win.frame.last):
    for widget in reverse(win.frame.last):
      if pointOnArea(widget, state.mx, state.my):
        result = widget
        break # Frame Found
  # Fallback to Root
  if isNil(result):
    result = win.root
  # Find at the Outermost if Hover is not inside
  var pivot {.cursor.} = win.hover
  if isNil(pivot) or pivot.outside() != result:
    pivot = result
  # Find Inside Widget
  result = pivot.find(state.mx, state.my)

proc prepareHover(win: GUIWindow, found: GUIWidget, state: ptr GUIState) =
  if (wGrab in found.flags) or found.kind in {wgPopup, wgMenu}:
    # Mark if is Inside Widget
    if found.pointOnArea(state.mx, state.my):
      found.flags.incl(wHover)
    else: found.flags.excl(wHover)
    # Hover Prepared
    return
  # Prepare Widget Hover
  let hover {.cursor.} = win.hover
  if found != hover:
    # Handle Remove Hover
    if not isNil(hover):
      hover.flags.excl(wHover)
      hover.vtable.handle(hover, outHover)
    # Handle Change Hover
    found.flags.incl(wHover)
    found.vtable.handle(found, inHover)
    # Change Previous Hover
    win.hover = found

proc prepareClick(win: GUIWindow, found: GUIWidget, state: ptr GUIState) =
  let kind = state.kind
  if kind == evCursorClick:
    found.flags.incl(wGrab)
    # Elevate if is a Frame
    let frame = found.outside()
    if frame.kind == wgFrame:
      elevate(win.frame, frame)
  # Remove Widget Grab
  elif kind == evCursorRelease:
    found.flags.excl(wGrab)

# ---------------------------
# Window Event Dispatch Procs
# ---------------------------

proc widgetEvent(win: GUIWindow, state: ptr GUIState) =
  var
    found {.cursor.}: GUIWidget
    enabled: bool
  # Dispatch Check
  case state.kind
  of evCursorMove, evCursorClick, evCursorRelease:
    found = win.findHover(state)
    win.prepareHover(found, state)
    # Check if widget is Enabled
    enabled = wMouse in found.flags
    # Prepare Widget Grab
    if enabled:
      win.prepareClick(found, state)
  of evKeyDown, evKeyUp:
    found = win.findFocus(state)
    if isNil(found):
      return
    # TODO: dispatch callback based hotkeys instead root
    # TODO: Check focus step in state translation
    # Check if widget is enabled
    enabled = wKeyboard in found.flags
  # Dispatch Widget Event
  if enabled:
    found.vtable.event(found, state)

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
        send(win.root.target, wsLayout)
    else: # Check if the event is valid for be processed by a widget
      if translateXEvent(win.state, win.display, addr event, win.xic):
        win.widgetEvent(addr win.state)

# ------------------------------
# Window Callback Dispatch Procs
# ------------------------------

proc check(win: GUIWindow, widget: GUIWidget) =
  # Check if is still focused
  if widget == win.focus and
  wFocusable + {wFocus} notin widget.flags:
    widget.flags.excl(wFocus)
    widget.vtable.handle(widget, outFocus)
    # Remove Focus
    win.focus = nil

proc focus(win: GUIWindow, widget: GUIWidget) =
  let focus {.cursor.} = win.focus
  if widget != win.root and
  wFocusable in widget.flags and
  widget != focus:
    # Handle Focus Out
    if not isNil(focus):
      focus.flags.excl(wFocus)
      focus.vtable.handle(focus, outFocus)
    # Handle Focus In
    widget.flags.incl(wFocus)
    widget.vtable.handle(widget, inFocus)
    # Replace Focus
    win.focus = widget

# -- TODO: change dirty naming
proc dirty(win: GUIWindow, widget: GUIWidget) =
  if wVisible in widget.flags:
    # Arrange Widget and Check Focus
    widget.arrange()
    win.check(widget)

proc handleSignals*(win: GUIWindow): bool =
  for signal in poll(win.queue):
    case signal.kind
    of sCallback, sCallbackEX:
      signal.call()
    of sWidget:
      let widget =
        cast[GUIWidget](signal.target)
      case signal.ws
      of wsLayout: dirty(win, widget)
      of wsFocus: focus(win, widget)
      # Window Layer Widget
      of wsOpen: open(win, widget)
      of wsClose: close(win, widget)
    of sWindow:
      case signal.msg
      of wsOpenIM: XSetICFocus(win.xic)
      of wsCloseIM: XUnsetICFocus(win.xic)
      of wsFocusOut: # Un Focus
        let focus {.cursor.} = win.focus
        if not isNil(focus):
          focus.flags.excl(wFocus)
          focus.vtable.handle(focus, outFocus)
          # Remove Focus
          win.focus = nil
      of wsHoverOut: # Un Hover
        let hover {.cursor.} = win.hover
        if not isNil(hover):
          hover.flags.excl(wHoverGrab)
          hover.vtable.handle(hover, outHover)
          # Remove Hover
          win.hover = nil
      of wsTerminate: 
        return true

# -------------------
# GUI Rendering Procs
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
