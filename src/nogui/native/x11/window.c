#include "x11.h"
#include <locale.h>
#include <stdlib.h>

static const EGLint attr_egl[] = {
  // Color Channels
  EGL_RED_SIZE, 8,
  EGL_GREEN_SIZE, 8,
  EGL_BLUE_SIZE, 8,
  // Render Type
  EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
  EGL_NONE
};

static const EGLint attr_context[] = {
  EGL_CONTEXT_MAJOR_VERSION, 3,
  EGL_CONTEXT_MINOR_VERSION, 3,
  EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
  EGL_NONE
};

static const EGLint attr_surface[] = {
  EGL_RENDER_BUFFER, EGL_BACK_BUFFER,
  EGL_NONE
};

// OpenGL Version Info
typedef char* (*GLGETSTRING)(int name);

// -------------------------
// X11 Native Initialization
// -------------------------

static void x11_create_egl(nogui_native_t* native, Window XID) {
  EGLDisplay egl_display;
  EGLConfig egl_config;
  EGLContext egl_context;
  EGLSurface egl_surface;
  // EGL Version
  int num_config;
  int major, minor;

  // Create EGL Display
  eglBindAPI(EGL_OPENGL_API);
  egl_display = eglGetDisplay(native->display);
  if (!egl_display)
    log_error("failed creating EGLDisplay");

  // Initialize EGL and Choose GL Config
  eglInitialize(egl_display, &major, &minor);
  eglChooseConfig(
    egl_display,
    attr_egl,
    &egl_config,
    1, &num_config
  );

  if (!egl_config)
    log_error("failed creating EGLConfig");

  // Create EGL Context and Surface
  egl_context = eglCreateContext(
    egl_display, egl_config, EGL_NO_CONTEXT, attr_context);
  egl_surface = eglCreateWindowSurface(
    egl_display, egl_config, XID, attr_surface);

  if (!egl_context)
    log_error("failed creating EGLContext");
  else if (!egl_surface)
    log_error("failed creating EGLSurface");

  // Make Surface Current
  eglMakeCurrent(
    egl_display,
    egl_surface,
    egl_surface,
    egl_context
  );
  
  // Disable V-Sync
  eglSwapInterval(egl_display, 0);

  // Store EGL Session
  native->egl_display = egl_display;
  native->egl_config = egl_config;
  native->egl_context = egl_context;
  native->egl_surface = egl_surface;
  // Store EGL GetProcAddress Function
  native->info.gl_loader = (nogui_getProcAddress_t) eglGetProcAddress;

  // -- Logging EGL & OpenGL Version --
  GLGETSTRING glGetString = (GLGETSTRING) eglGetProcAddress("glGetString");
  const char* vendor = glGetString(0x1F02);
  log_info("EGL Version: %d.%d", major, minor);
  log_info("GL Version: %s", vendor);
}

static void x11_create_xim(nogui_native_t* native, Window XID) {
  if (!setlocale(LC_ALL, "") || !XSetLocaleModifiers(""))
    log_warning("proper C locale not found");

  Display* display = native->display;
  XIM xim; XIC xic;

  // Try Create Input Method
  xim = XOpenIM(display, NULL, NULL, NULL);
  if (!xim) {
    XSetLocaleModifiers("@im=none");
    xim = XOpenIM(display, NULL, NULL, NULL);
    // Warns About Fallback Context Created
    log_warning("fallback XIM context used");
  }

  // Create Input Context
  const long mask = XIMPreeditNothing | XIMStatusNothing;
  xic = XCreateIC(xim, 
    XNInputStyle, mask,
    XNClientWindow, XID, 
    NULL
  );

  if (!xic)
    log_warning("failed creating XIM context");

  // Store X11 Input Method
  native->xim = xim;
  native->xic = xic;
}

static Window x11_create_window(nogui_native_t* native, int w, int h) {
  Window XID;
  // Window Attributes
  XSetWindowAttributes attr;
  attr.event_mask =
    ExposureMask |
    KeyPressMask |
    KeyReleaseMask |
    StructureNotifyMask;

  // Create X11 With Default Flags
  Window root = DefaultRootWindow(native->display);
  XID = XCreateWindow(native->display, root, 0, 0, w, h, 0,
    CopyFromParent, CopyFromParent, NULL, CWEventMask, &attr);
  
  if (XID == 0)
    log_error("failed creating X11 window");

  return XID;
}

// -------------------------
// X11 Native Initialization
// -------------------------

nogui_native_t* nogui_native_init(int w, int h) {
  // Create X11 Display Connection
  nogui_native_t* native = malloc(sizeof(nogui_native_t));
  native->display = XOpenDisplay(NULL);

  // Create X11 Window and EGL Context
  Window XID = x11_create_window(native, w, h);
  x11_create_xim(native, XID);
  x11_create_egl(native, XID);
  native->XID = XID;

  // Initialize XInput2
  x11_xinput2_init(native);

  // Register Window Close
  Atom window_close = XInternAtom(
    native->display, "WM_DELETE_WINDOW", False);
  XSetWMProtocols(native->display, XID, &window_close, 1);
  native->window_close = window_close;

  // Initialize Native Info
  native->info.width = w;
  native->info.height = h;
  // Initialize Native State
  native->state.native = native;
  native->state.utf8str = malloc(16);
  native->state.utf8cap = 16;
  // Initialize Native Queue
  native->queue = (nogui_queue_t) {};

  return native;
}

// --------------------
// X11 Native Execution
// --------------------

int nogui_native_open(nogui_native_t* native) {
  int result = XMapWindow(native->display, native->XID);
  if (result == BadWindow)
    log_error("failed opening window on X11");

  // Flush Window Open Command
  XSync(native->display, 0);
  return result;
}

void nogui_native_frame(nogui_native_t* native) {
  eglSwapBuffers(native->egl_display, native->egl_surface);
}

// ------------------
// X11 Native Destroy
// ------------------

void nogui_native_destroy(nogui_native_t* native) {
  // Close X11 Window from Display
  XUnmapWindow(native->display, native->XID);

  // Destroy EGL Context
  eglDestroySurface(native->egl_display, native->egl_surface);
  eglDestroyContext(native->egl_display, native->egl_context);
  eglTerminate(native->egl_display);

  // Destroy X11 Display
  XDestroyIC(native->xic);
  XCloseIM(native->xim);
  XDestroyWindow(native->display, native->XID);
  XCloseDisplay(native->display);

  // Destroy X11 Residuals
  x11_xinput2_destroy(native);
  // TODO: first class IME support
  if (native->state.utf8str)
    free(native->state.utf8str);

  // Dealloc Native Platform
  nogui_queue_destroy(&native->queue);
  free(native);
}

// ---------------------------
// X11 Native Objects Pointers
// ---------------------------

nogui_info_t* nogui_native_info(nogui_native_t* native) {
  return &native->info;
}

nogui_queue_t* nogui_native_queue(nogui_native_t* native) {
  return &native->queue;
}

nogui_state_t* nogui_native_state(nogui_native_t* native) {
  return &native->state;
}
