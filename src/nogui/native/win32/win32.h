#ifndef NOGUI_WIN32_H
#define NOGUI_WIN32_H
#include "../native.h"
// Include Win32 API
#include <windows.h>

// -----------------------------
// GUI Win32 Forward Declaration
// -----------------------------

#define VM_STACK_SIZE 0x100000
typedef __attribute__((aligned(16))) struct {
  UCHAR buffer[VM_STACK_SIZE];
} win32_vmstack_t;

typedef __attribute__((aligned(16))) struct {
  DWORD64 buffer[32];
} win32_vmstate_t;

typedef enum {
  VM_NOTHING,
  VM_RUNNING,
  VM_FINALIZED,
  VM_ESCAPE,
  VM_PAUSE
} win32_vmcode_t;

typedef struct win32_green_t win32_green_t;
typedef void (*win32_vmproc_t)(void*);
typedef void (*win32_vmfunc_t)(win32_green_t*, void*);
struct win32_green_t {
    win32_vmstate_t vm;
    win32_vmstate_t host;
    win32_vmstack_t stack;
    win32_vmcode_t code;
    // Procedure Data
    win32_vmfunc_t proc;
    void* data;
};

struct nogui_native_t {
    win32_green_t* green;
    // Win32 Objects
    HWND hwnd;
    HDC hdc;
    HGLRC hglrc;

    // nogui export
    nogui_info_t info;
    nogui_queue_t queue;
    nogui_state_t state;
    nogui_state_t state0;
};

// Win32 WinTab Manager
void win32_wintab_init(HWND hwnd);
void win32_wintab_destroy(HWND hwnd);
BOOL win32_wintab_active(WPARAM wParam, LPARAM lParam);
BOOL win32_wintab_packet(nogui_state_t* state, WPARAM wParam, LPARAM lParam);
void win32_wintab_status(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

// Win32 Keyboard Charcodes
nogui_keycode_t win32_keymap_lookup(WPARAM wParam);
nogui_keymask_t win32_keymask_lookup();
int win32_keycode_utf8(WCHAR wide, CHAR* buffer, int size);

// Win32 Green Thread
extern void win32_green_callctx(win32_vmproc_t proc, void* p, void* stack);
extern void win32_green_jumpctx(win32_vmstate_t* state, int call);
extern int win32_green_setctx(win32_vmstate_t* state);

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
#endif // NOGUI_WIN32_H
