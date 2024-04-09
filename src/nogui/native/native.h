#ifndef NOGUI_NATIVE_H
#define NOGUI_NATIVE_H
// Platform Independent Keycodes
#include "keymap.h"

void log_error(const char* format, ... );
void log_warning(const char* format, ... );
void log_info(const char* format, ... );

// -------------------------
// GUI Native Opaque Objects
// -------------------------

struct nogui_native_t;
struct nogui_cursor_t;

typedef struct nogui_native_t nogui_native_t;
typedef struct nogui_cursor_t nogui_cursor_t;
// OpenGL Function Address Loader, used by glad
typedef void* (*nogui_getProcAddress_t)(const char* name);

typedef struct {
  char* title;
  int width, height;
  nogui_cursor_t* cursor;
  // OpenGL Function Loader
  int gl_major, gl_minor;
  nogui_getProcAddress_t gl_loader;
} nogui_info_t;

// ---------------------------------
// GUI Native Event Objects
// TODO: special events like XInput2
// ---------------------------------

// GUI State Enums
typedef enum {
  devStylus,
  devEraser,
  devMouse
} nogui_tool_t;

typedef enum {
  evUnknown,
  evFlush,
  evPending,
  // Cursor Events
  evCursorMove,
  evCursorClick,
  evCursorRelease,
  // Key Events
  evKeyDown,
  evKeyUp,
  evNextFocus,
  evPrevFocus,
  // Window Events
  evWindowExpose,
  evWindowResize,
  evWindowEnter,
  evWindowLeave,
  evWindowClose
} nogui_event_t;

typedef struct {
  nogui_native_t* native;
  void **queue, **cherry;
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

// -------------------
// GUI Native Procs
// TODO: Clipboard
// TODO: Drag and Drop
// -------------------

// GUI Native Object
nogui_native_t* nogui_native_init(int w, int h);
int nogui_native_execute(nogui_native_t* native);
void nogui_native_frame(nogui_native_t* native);
nogui_info_t* nogui_native_info(nogui_native_t* native);
void nogui_native_destroy(nogui_native_t* native);

// GUI Native Event
nogui_state_t* nogui_native_state(nogui_native_t* native);
void nogui_state_poll(nogui_state_t* state);
int nogui_state_next(nogui_state_t* state);

// GUI Native Properties
void nogui_window_title(nogui_native_t* native, char* title);
void nogui_window_cursor(nogui_native_t* native, nogui_cursor_t* cursor);

#endif // NOGUI_NATIVE_H
