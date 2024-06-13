#ifndef NOGUI_WIN32_H
#define NOGUI_WIN32_H
#include "../native.h"
// Include Win32 API
#include <windows.h>

// -----------------------------
// GUI Win32 Forward Declaration
// -----------------------------

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
