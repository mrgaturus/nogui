#ifndef NOGUI_WIN32_H
#define NOGUI_WIN32_H
#include "../native.h"
// Include Win32 API
#include <windows.h>

// -----------------------------
// GUI Win32 Forward Declaration
// -----------------------------
#define NOGUI_DESTROY (WM_APP + 1)

nogui_keycode_t win32_keymap_lookup(WPARAM wParam);
nogui_keymask_t win32_keymask_lookup();
// UTF18 Wide Character to UTF8 Multibyte
int win32_keycode_utf8(WCHAR wide, CHAR* buffer, int size);

struct nogui_native_t {
    DWORD id;
    HANDLE thrd;
    // WGL Context
    HDC hdc;
    HGLRC hglrc;

    // Threaded HWND
    nogui_queue_t csQueue;
    nogui_state_t csState;
    CRITICAL_SECTION csWait;
    HANDLE evWait;

    // nogui export
    nogui_info_t info;
    nogui_queue_t queue;
    nogui_state_t state;
};

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
#endif // NOGUI_WIN32_H
