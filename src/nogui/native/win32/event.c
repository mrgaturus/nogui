#include "win32.h" // IWYU pragma: keep
#include <windowsx.h>
#include <wintab.h>
#include <string.h>

// ------------------------------
// GUI Native Event: Green Thread
// ------------------------------

static void win32_green_payload(win32_green_t* green) {
    green->proc(green, green->data);
    win32_green_jumpctx(&green->host, VM_FINALIZED);
}

static void win32_green_call(win32_green_t* green, win32_vmfunc_t proc, void* p) {
    if (green->code == VM_NOTHING)
        green->code = win32_green_setctx(&green->host);
    // Manage Green Thread Status
    switch (green->code) {
        case VM_NOTHING: {
            green->proc = proc;
            green->data = p;
            green->code = VM_RUNNING;
            
            void* stack = &green->stack.buffer[VM_STACK_SIZE];
            win32_vmproc_t proc = (win32_vmproc_t) win32_green_payload;
            win32_green_callctx(proc, green, stack);
        } break;
        case VM_RUNNING: break;
        case VM_FINALIZED:
            green->code = VM_NOTHING;
            break;
        case VM_ESCAPE:
            green->code = VM_PAUSE;
            break;
        case VM_PAUSE:
            green->code = VM_RUNNING;
            win32_green_jumpctx(&green->vm, VM_RUNNING);
            break;
    }
}

static void win32_green_escape(win32_green_t* green) {
    if (green->code == VM_RUNNING) {
        if (win32_green_setctx(&green->vm) != VM_RUNNING)
            win32_green_jumpctx(&green->host, VM_ESCAPE);
    }
}

// -----------------------
// GUI Native Event: Queue
// -----------------------

static void win32_send_event(nogui_native_t* native, nogui_state_t* state) {
    nogui_queue_t* queue = &native->queue;

    // Create a Native Callback
    const long size = sizeof(nogui_state_t);
    nogui_cb_t* cb = nogui_cb_create(size);
    cb->fn = queue->cb_event.fn;
    cb->self = queue->cb_event.self;
    // Define Current State
    nogui_state_t* s = nogui_cb_data(cb);
    memcpy(s, state, size);

    // Send Native Callback
    nogui_queue_push(queue, cb);
}

// ---------------------------
// GUI Native Event: Translate
// ---------------------------

static BOOL win32_event_mouse(nogui_state_t* state, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    // Mouse Coordinates if not WinTab found
    if (win32_wintab_active(wParam, lParam) == FALSE) {
        state->tool = devMouse;
        state->mx = GET_X_LPARAM(lParam);
        state->my = GET_Y_LPARAM(lParam);
        state->px = (float) state->mx;
        state->py = (float) state->my;
        state->pressure = 1.0;
    } else if (state->kind == evCursorMove)
        return TRUE;

    // Lookup Which Button Pressed
    nogui_keycode_t key = state->key;
    switch (uMsg) {
        case WM_LBUTTONDOWN:
        case WM_LBUTTONUP:
            key = Button_Left; break;
        case WM_RBUTTONDOWN: 
        case WM_RBUTTONUP:
            key = Button_Right; break;
        case WM_MBUTTONDOWN:
        case WM_MBUTTONUP:
            key = Button_Middle; break;
        case WM_XBUTTONDOWN:
        case WM_XBUTTONUP:
            key = GET_XBUTTON_WPARAM(wParam) == XBUTTON1 ?
                Button_X1 : Button_X2;
            break;
    }

    // Change Current Key Pressed
    state->mask = win32_keymask_lookup() & 0xF;
    state->key = key;
    // Continue Event
    return 0;
}

static BOOL win32_event_keyboard(nogui_state_t* state, HWND hwnd, UINT uMsg, WPARAM wParam) {
    state->key = win32_keymap_lookup(wParam);
    state->mask = win32_keymask_lookup();
    // Clear UTF8 Character
    state->utf8size = 0;
    state->utf8char[0] = '\0';

    // Check if was Pressed or not
    switch (uMsg) {
        case WM_KEYDOWN:
        case WM_SYSKEYDOWN:
            state->kind = evKeyDown;
            break;
        case WM_KEYUP:
        case WM_SYSKEYUP:
            state->kind = evKeyUp;
            break;
    }

    // Check Alt + F4 Key Combination
    if (state->key == NK_F4 && (state->mask & 0xF) == Mod_Alt) {
        if (state->kind == evKeyDown)
            state->kind = evWindowClose;
    // Check Focus Cycle Key Combinations
    } else if (state->key == NK_Tab && state->kind == evKeyDown) {
        if ((state->mask & 0xF) == Mod_Shift)
            state->kind = evFocusPrev;
        else state->kind = evFocusNext;
    }

    MSG msg = { 0 };
    // Forward Message to WM_CHAR
    PeekMessage(&msg, hwnd, 0, 0, PM_NOREMOVE);
    return msg.message == WM_CHAR;
}

// --------------------------
// GUI Native Event: Dispatch
// --------------------------

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    static nogui_native_t* native;
    static nogui_state_t* state;
    static win32_green_t* green;
    static BOOL anticlick;
    // Handle WinTab Status Changes
    win32_wintab_status(hwnd, uMsg, wParam, lParam);

    switch (uMsg) {
        case WM_CREATE:
            native = *(nogui_native_t**) lParam;
            state = &native->state0;
            green = native->green;
            goto SEND_DEFAULT;
        case WM_ACTIVATE:
            anticlick = (wParam == WA_CLICKACTIVE);
            goto SEND_DEFAULT;

        // Tablet Window Events
        case WT_PACKET:
            if (win32_wintab_packet(state, wParam, lParam) == 0)
                goto SEND_DEFAULT;
            else goto SEND_EVENT;

        // Mouse Window Events
        case WM_MOUSEMOVE:
            state->kind = evCursorMove;
            if (win32_event_mouse(state, uMsg, wParam, lParam))
                goto SEND_DEFAULT;
            else goto SEND_EVENT;
        case WM_LBUTTONDOWN:
        case WM_RBUTTONDOWN:
        case WM_MBUTTONDOWN:
        case WM_XBUTTONDOWN:
            SetCapture(hwnd);
            if (anticlick)
                goto SEND_DEFAULT;

            state->kind = evCursorClick;
            win32_event_mouse(state, uMsg, wParam, lParam);
            goto SEND_EVENT;
        case WM_LBUTTONUP:
        case WM_RBUTTONUP:
        case WM_MBUTTONUP:
        case WM_XBUTTONUP:
            ReleaseCapture();
            if (anticlick) {
                anticlick = FALSE;
                goto SEND_DEFAULT;
            }

            state->kind = evCursorRelease;
            win32_event_mouse(state, uMsg, wParam, lParam);
            goto SEND_EVENT;

        // Keyboard Window Events
        case WM_KEYDOWN:
        case WM_KEYUP:
        case WM_SYSKEYDOWN:
        case WM_SYSKEYUP:
            if (win32_event_keyboard(state, hwnd, uMsg, wParam))
                goto SEND_DEFAULT;
            else goto SEND_EVENT;
        // Keyboard UTF8 Char
        case WM_CHAR:
            state->utf8size = win32_keycode_utf8(
                wParam, state->utf8char, 8);
            goto SEND_EVENT;

        // Frame Window Blocking
        case WM_ENTERSIZEMOVE:
        case WM_ENTERMENULOOP:
            SetTimer(hwnd, (UINT_PTR) native, 
                USER_TIMER_MINIMUM, NULL);
            goto SEND_DEFAULT;

        case WM_SIZE:
            state->kind = evWindowResize;
            native->info.width = LOWORD(lParam);
            native->info.height = HIWORD(lParam);
            win32_send_event(native, state);
        case WM_MOVE:
            win32_green_escape(green);
            goto SEND_DEFAULT;
        case WM_TIMER:
            if (wParam == (UINT_PTR) native)
                win32_green_escape(green);
            goto SEND_DEFAULT;

        case WM_EXITSIZEMOVE:
        case WM_EXITMENULOOP:
            KillTimer(hwnd, (UINT_PTR) native);
            goto SEND_DEFAULT;

        // Frame Window Events
        case WM_CLOSE:
            state->kind = evWindowClose;
            goto SEND_EVENT;

        // Disable Alt Menu
        case WM_SYSCOMMAND:
            if ((wParam & 0xFFF0) == SC_KEYMENU)
                return 0;
            goto SEND_DEFAULT;
        case WM_DISPLAYCHANGE:
            goto SEND_DEFAULT;

        // Process Event Default
        case WM_PAINT:
            state->kind = evWindowExpose;
            win32_send_event(native, state);
            win32_green_escape(green);
        default: goto SEND_DEFAULT;
    }

SEND_EVENT:
    win32_send_event(native, state);
    return 0;

SEND_DEFAULT:
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

// -------------------------
// GUI Native Event: Pooling
// -------------------------

void win32_green_pump(win32_green_t* green, nogui_native_t* native) {
    MSG msg = { 0 };
    HWND hwnd = native->hwnd;
    // Peek Current Accumulated Messages
    while (PeekMessage(&msg, hwnd, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
}

void nogui_native_pump(nogui_native_t* native) {
    win32_green_call(native->green,
        (win32_vmfunc_t) win32_green_pump, native);
}

int nogui_native_poll(nogui_native_t* native) {
    nogui_queue_t* queue = &native->queue;
    nogui_cb_t* cb = queue->first;
    // Copy Callback State to Current State
    if (cb && cb->fn == queue->cb_event.fn) {
        void* data = nogui_cb_data(cb);
        memcpy(&native->state, data, sizeof(nogui_state_t));
        native->state.utf8str = native->state.utf8char;
    }

    return nogui_queue_poll(queue);
}
