#ifndef NOGUI_NATIVE_H
#define NOGUI_NATIVE_H
// Platform Independent Keycodes
#include "keymap.h"

void log_error(const char* format, ... );
void log_warning(const char* format, ... );
void log_info(const char* format, ... );

// ------------------
// GUI Native Objects
// ------------------

struct nogui_native_t;
struct nogui_cursor_t;

typedef long long nogui_time_t;
typedef struct nogui_native_t nogui_native_t;
typedef struct nogui_cursor_t nogui_cursor_t;
// OpenGL Function Address Loader, used by glad
typedef void* (*nogui_getProcAddress_t)(const char* name);

typedef struct {
  int w, h;
  int ox, oy;
  // Buffer Pixels RGBA
  unsigned char* pixels;
} nogui_bitmap_t;

typedef enum {
  cursorArrow,
  cursorCross,
  cursorMove,
  cursorWaitHard,
  cursorWaitSoft,
  cursorForbidden,
  cursorText,
  cursorTextUp,
  // Hand Cursors
  cursorHandPoint,
  cursorHandHover,
  cursorHandGrab,
  // Zoom Cursors
  cursorZoomIn,
  cursorZoomOut,
  // Resize Cursors
  cursorSizeVertical,
  cursorSizeHorizontal,
  cursorSizeDiagLeft,
  cursorSizeDiagRight,
  // Resize Dock Cursors
  cursorSplitVertical,
  cursorSplitHorizontal
} nogui_cursorsys_t;

typedef struct {
  char *id, *title;
  int width, height;
  // OpenGL Function Loader
  int gl_major, gl_minor;
  nogui_getProcAddress_t gl_loader;
} nogui_info_t;

// ------------------------
// GUI Native Queue Objects
// : Platform Independent
// ------------------------

struct nogui_cb_t;
typedef void (*nogui_proc_t)(void*, void*);
typedef struct nogui_cb_t nogui_cb_t;

struct nogui_cb_t {
  nogui_cb_t* next;
  // Callback Proc
  void *self;
  nogui_proc_t fn;
  // Callback Bytes
  long bytes;
};

typedef struct {
  nogui_cb_t* first;
  nogui_cb_t* stack;
  nogui_cb_t* once;
  // Event Callback
  nogui_cb_t cb_event;
} nogui_queue_t;

// ------------------------
// GUI Native Event Objects
// ------------------------

// GUI State Enums
typedef enum {
  devStylus,
  devEraser,
  devMouse
} nogui_tool_t;

typedef enum {
  evUnknown,
  // Cursor Events
  evCursorMove,
  evCursorClick,
  evCursorRelease,
  // Key Events
  evKeyDown,
  evKeyUp,
  evFocusNext,
  evFocusPrev,
  // Window Events
  evWindowExpose,
  evWindowResize,
  evWindowEnter,
  evWindowLeave,
  evWindowClose
} nogui_event_t;

typedef struct {
  nogui_native_t* native;
  // State Kind and Tool
  nogui_event_t kind;
  nogui_tool_t tool;
  // Cursor State
  int mx, my;
  float px, py;
  float pressure;
  // Keyboard State
  nogui_keycode_t key;
  nogui_keymask_t mask;
  unsigned int scan;
  // Input Method Dummy
  // TODO: first class IME support
  int utf8state;
  int utf8cap, utf8size;
  char* utf8str;
} nogui_state_t;

// -------------------------
// GUI Native Monotime Procs
// -------------------------

nogui_time_t nogui_time_now();
nogui_time_t nogui_time_ms(int ms);
void nogui_time_sleep(nogui_time_t time);

// ----------------------
// GUI Native Queue Procs
// ----------------------

// GUI Native Queue Callback
nogui_cb_t* nogui_cb_create(int bytes);
void* nogui_cb_data(nogui_cb_t* cb);
void nogui_cb_call(nogui_cb_t* cb);

// GUI Native Queue Push
void nogui_queue_push(nogui_queue_t* queue, nogui_cb_t* cb);
void nogui_queue_relax(nogui_queue_t* queue, nogui_cb_t* cb);
// GUI Native Queue Pop
int nogui_queue_poll(nogui_queue_t* queue);
void nogui_queue_destroy(nogui_queue_t* queue);

// ----------------------------
// GUI Native Propierties Procs
// ----------------------------

// GUI Native Cursor
nogui_cursor_t* nogui_cursor_custom(nogui_native_t* native, nogui_bitmap_t bm);
nogui_cursor_t* nogui_cursor_sys(nogui_native_t* native, nogui_cursorsys_t id);
void nogui_cursor_destroy(nogui_native_t* native, nogui_cursor_t* cursor);

// GUI Native Cursor Property
void nogui_native_cursor(nogui_native_t* native, nogui_cursor_t* cursor);
void nogui_native_cursor_reset(nogui_native_t* native);
// GUI Native Identifier Property
void nogui_native_id(nogui_native_t* native, char* id);
void nogui_native_title(nogui_native_t* native, char* title);

// -------------------------
// GUI Native Platform Procs
// -------------------------

// GUI Native Platform
nogui_native_t* nogui_native_init(int w, int h);
int nogui_native_open(nogui_native_t* native);
void nogui_native_frame(nogui_native_t* native);
void nogui_native_destroy(nogui_native_t* native);

// GUI Native Objects
nogui_info_t* nogui_native_info(nogui_native_t* native);
nogui_queue_t* nogui_native_queue(nogui_native_t* native);
nogui_state_t* nogui_native_state(nogui_native_t* native);

// GUI Native Event Pooling
void nogui_native_pump(nogui_native_t* native);
int nogui_native_poll(nogui_native_t* native);

#endif // NOGUI_NATIVE_H
