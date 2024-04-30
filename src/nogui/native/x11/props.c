#include "x11.h"
#include <X11/Xcursor/Xcursor.h>
#include <stdlib.h>

// --------------------------
// GUI Native Cursor Creation
// --------------------------

nogui_cursor_t* nogui_cursor_custom(nogui_native_t* native, nogui_bitmap_t bm) {
  XcursorImage* img = XcursorImageCreate(bm.w, bm.h);
  int bytes = sizeof(XcursorPixel) * bm.w * bm.h;

  // Define Cursor Header
  img->version = 1;
  img->size = bytes;
  // Define Hotspot
  img->xhot = bm.ox;
  img->yhot = bm.oy;
  // Define Pixels Temporal Buffer
  img->pixels = (XcursorPixel*) bm.pixels;

  char* dst = (char*) img->pixels;
  // Convert Bitmap to BGRA 32bit
  for (int i = 0; i < bytes; i += 4) {
    char aux = dst[i];
    dst[i] = dst[i + 2];
    dst[i + 2] = aux;
  }

  // Create Native X11 Cursor
  Cursor cursor = XcursorImageLoadCursor(native->display, img);
  XcursorImageDestroy(img);
  // Return Native Cursor
  return (nogui_cursor_t*) cursor;
}

nogui_cursor_t* nogui_cursor_sys(nogui_native_t* native, nogui_cursorsys_t id) {
  const static char* cursor_x11[] = {
    "left_ptr",
    "cross",
    "fleur",
    "watch",
    "left_ptr_watch",
    "crossed_circle",
    "xterm",
    "vertical-text",
    // Hand Cursors
    "pointing_hand",
    "openhand",
    "closedhand",
    // Zoom Cursors
    "zoom-in",
    "zoom-out",
    // Resize Cursors
    "size_ver",
    "size_hor",
    "size_fdiag",
    "size_bdiag",
    // Resize Dock Cursors
    "split_v",
    "split_h"
  };

  // Load System Theme Cursor and Return
  Cursor cursor = XcursorLibraryLoadCursor(native->display, cursor_x11[id]);
  return (nogui_cursor_t*) cursor;
}

// -----------------------------
// GUI Native Cursor Destruction
// -----------------------------

void nogui_cursor_destroy(nogui_native_t* native, nogui_cursor_t* cursor) {
  XFreeCursor(native->display, (Cursor) cursor);
}

// --------------------------
// GUI Native Cursor Property
// --------------------------

void nogui_native_cursor(nogui_native_t* native, nogui_cursor_t* cursor) {
  XDefineCursor(native->display, native->XID, (Cursor) cursor);
}

void nogui_native_cursor_reset(nogui_native_t* native) {
  XUndefineCursor(native->display, native->XID);
}

// ------------------------------
// GUI Native Identifier Property
// ------------------------------

void nogui_native_id(nogui_native_t* native, char* id) {

}

void nogui_natives_title(nogui_native_t* native, char* title) {

}
