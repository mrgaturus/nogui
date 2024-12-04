#include "win32.h" // IWYU pragma: keep
#include <string.h>

// --------------------------
// GUI Native Cursor Creation
// --------------------------

nogui_cursor_t* nogui_cursor_custom(nogui_native_t* native, nogui_bitmap_t bm) {
  int bytes = sizeof(unsigned int) * bm.w * bm.h;

  // Define Cursor Bitmap
  BITMAPV4HEADER bmh = {
    .bV4Size = sizeof(BITMAPV4HEADER),
    .bV4Width = bm.w,
    .bV4Height = -bm.h,
    .bV4Planes = 1,
    .bV4BitCount = 32,
    .bV4V4Compression = BI_BITFIELDS,
    .bV4RedMask = 0x00FF0000,
    .bV4GreenMask = 0x0000FF00,
    .bV4BlueMask = 0x000000FF,
    .bV4AlphaMask = 0xFF000000,
  };

  char* dst = (char*) bm.pixels;
  // Convert Bitmap to BGRA 32bit
  for (int i = 0; i < bytes; i += 4) {
    char aux = dst[i];
    dst[i] = dst[i + 2];
    dst[i + 2] = aux;
  }

  // Create Cursor HBITMAP
  void *pBits;
  HDC hdc = GetDC(NULL);
  HBITMAP hBitmap = CreateDIBSection(hdc,
    (BITMAPINFO*) &bmh, DIB_RGB_COLORS, &pBits, NULL, 0);
  ReleaseDC(NULL, hdc);
  // Check if Bitmap Created
  if (!hBitmap)
    return NULL;

  // Define Cursor Properties
  ICONINFO iconInfo = {
    .fIcon = FALSE, // Cursor
    .xHotspot = bm.ox,
    .yHotspot = bm.oy,
    .hbmMask = hBitmap,
    .hbmColor = hBitmap
  };

  // Copy Pixel Buffer to HBITMAP and Create Cursor
  memcpy(pBits, bm.pixels, bytes);
  HCURSOR hCursor = CreateIconIndirect(&iconInfo);
  // Return Created Cursor
  return (nogui_cursor_t*) hCursor;
}

nogui_cursor_t* nogui_cursor_sys(nogui_native_t* native, nogui_cursorsys_t id) {
  HCURSOR cursor;

  switch (id) {
    case cursorArrow: cursor = LoadCursor(NULL, IDC_ARROW); break;
    case cursorCross: cursor = LoadCursor(NULL, IDC_CROSS); break;
    case cursorMove: cursor = LoadCursor(NULL, IDC_SIZEALL); break;
    case cursorWaitHard: cursor = LoadCursor(NULL, IDC_WAIT); break;
    case cursorWaitSoft: cursor = LoadCursor(NULL, IDC_APPSTARTING); break;
    case cursorForbidden: cursor = LoadCursor(NULL, IDC_NO); break;
    case cursorText: cursor = LoadCursor(NULL, IDC_IBEAM); break;
    case cursorTextUp: cursor = LoadCursor(NULL, IDC_IBEAM); break;
    case cursorPoint: cursor = LoadCursor(NULL, IDC_HAND); break;

    // Resize Cursors
    case cursorSizeVertical: cursor = LoadCursor(NULL, IDC_SIZENS); break;
    case cursorSizeHorizontal: cursor = LoadCursor(NULL, IDC_SIZEWE); break;
    case cursorSizeDiagLeft: cursor = LoadCursor(NULL, IDC_SIZENWSE); break;
    case cursorSizeDiagRight: cursor = LoadCursor(NULL, IDC_SIZENESW); break;

    // Resize Dock Cursors
    case cursorSplitVertical: cursor = LoadCursor(NULL, IDC_SIZENS); break;
    case cursorSplitHorizontal: cursor = LoadCursor(NULL, IDC_SIZEWE); break;
  }

  return (nogui_cursor_t*) cursor;
}

void nogui_cursor_destroy(nogui_native_t* native, nogui_cursor_t* cursor) {
  DestroyCursor((HCURSOR) cursor);
}

// --------------------------
// GUI Native Cursor Property
// --------------------------

void nogui_native_cursor(nogui_native_t* native, nogui_cursor_t* cursor) {
  SetClassLongPtr(native->hwnd, GCLP_HCURSOR, (LONG_PTR) cursor);
  SetCursor((HCURSOR) cursor);
}

void nogui_native_cursor_reset(nogui_native_t* native) {
  nogui_cursor_t* arrow = nogui_cursor_sys(native, cursorArrow);
  nogui_native_cursor(native, arrow);
}

// ------------------------------
// GUI Native Identifier Property
// ------------------------------

void nogui_native_id(nogui_native_t* native, char* id, char* name) {
  if (native->info.id)
    free(native->info.id); 
  if (native->info.name)
    free(native->info.name);

  // Replace Native ID
  native->info.id = id;
  native->info.name = name;
}

void nogui_native_title(nogui_native_t* native, char* title) {
  int len = strlen(title);
  SetWindowText(native->hwnd, title);
  // Allocate Cache String
  char* cache = malloc(len);
  strcpy(cache, title);
  // Replace Current Cache
  if (native->info.title)
    free(native->info.title);
  native->info.title = cache;
}
