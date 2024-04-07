#ifndef NOGUI_X11_H
#define NOGUI_X11_H
#include "nogui/native/native.h"
// Include X11 and EGL
#include <X11/Xlib.h>
#include <EGL/egl.h>

typedef struct {
  xi2_device_t* next;
  // Device Identifier
  int id;
  nogui_tool_t tool;
  // Pressure Info
  int number;
  float min, max, last;
} xi2_device_t;

// ---------------------------
// GUI X11 Forward Declaration
// ---------------------------

struct nogui_native_t {
  Display* display;
  // Window Info
  Window XID;
  int w, h;
  // Input Method
  XIM xim;
  XIC xic;
  // Cursor Shape
  Cursor cursor;

  // XInput2 Devices
  int xi2_opcode;
  xi2_device_t* xi2_devices;
  // Window Close Message
  Atom window_close;

  // EGL Context
  EGLDisplay egl_display;
  EGLConfig egl_config;
  EGLContext egl_context;
  EGLSurface egl_surface;

  // nogui export
  nogui_info_t info;
  nogui_state_t state;
};

struct nogui_cursor_t {
  int x, d;
};

// -------------------------
// GUI X11 Private Functions
// -------------------------

void x11_xinput2_init(nogui_native_t* native);
void x11_xinput2_destroy(nogui_native_t* native);
void x11_xinput2_event(nogui_state_t* state, XEvent* event);

#endif // NOGUI_X11_H
