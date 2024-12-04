#ifndef NOGUI_WIN32_H
#define NOGUI_WIN32_H
#include "../native.h"
// Include Win32 API
#include <windows.h>

// -----------------------------
// GUI Win32 Forward Declaration
// -----------------------------

struct nogui_native_t {
    HWND hwnd;
    HDC hdc;
    HGLRC hglrc;

    // nogui export
    nogui_info_t info;
    nogui_queue_t queue;
    nogui_state_t state;
    nogui_state_t state0;
};

void win32_wintab_init(HWND hwnd);
void win32_wintab_destroy(HWND hwnd);
BOOL win32_wintab_active(WPARAM wParam, LPARAM lParam);
BOOL win32_wintab_packet(nogui_state_t* state, WPARAM wParam, LPARAM lParam);
void win32_wintab_status(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

nogui_keycode_t win32_keymap_lookup(WPARAM wParam);
nogui_keymask_t win32_keymask_lookup();
// UTF18 Wide Character to UTF8 Multibyte
int win32_keycode_utf8(WCHAR wide, CHAR* buffer, int size);

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
#endif // NOGUI_WIN32_H
