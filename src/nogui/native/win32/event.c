#include "win32.h" // IWYU pragma: keep
#include <windowsx.h>
#include <string.h>

// ----------------------
// GUI Native Event Queue
// ----------------------

static void win32_send_event(nogui_native_t* native, nogui_state_t* state) {
    nogui_queue_t* queue = &native->csQueue;

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

static void win32_pump_events(nogui_native_t* native) {
    nogui_queue_t* queue = &native->queue;
    nogui_queue_t* queue0 = &native->csQueue;

    nogui_cb_t* endpoint = queue0->first;
    // Add Endpoint to Main Queue
    if (endpoint) {
        nogui_cb_t* next = endpoint->next;
        nogui_queue_push(queue, endpoint);
        endpoint->next = next;
    }

    // Clear Thread Queue
    queue0->first = NULL;
    queue0->stack = NULL;
}

// --------------------------
// GUI Native Event Translate
// --------------------------

void win32_event_mouse(nogui_state_t* state, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    state->mx = GET_X_LPARAM(lParam);
    state->my = GET_Y_LPARAM(lParam);
    // TODO: wintab api
    state->px = (float) state->mx;
    state->py = (float) state->my;

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

    // Change Current Key
    state->key = key;
}

void win32_event_keyboard(nogui_state_t* state, WPARAM wParam) {
    state->key = wParam; // TODO: keymappings
    // Check if was Pressed or not
    if (wParam == WM_KEYDOWN)
        state->kind = evKeyDown;
    else if (wParam == WM_KEYUP)
        state->kind = evKeyUp;
}

// -------------------------
// GUI Native Event Dispatch
// -------------------------

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    static nogui_native_t* native;
    static nogui_state_t* state;

    LRESULT result = 0;
    switch (uMsg) {
        case WM_CREATE:
            native = *(nogui_native_t**) lParam;
            state = &native->csState;
            goto SEND_DEFAULT;

        // Mouse Window Events
        case WM_MOUSEMOVE:
            state->kind = evCursorMove;
            win32_event_mouse(state, uMsg, wParam, lParam);
            break;
        case WM_LBUTTONDOWN:
        case WM_RBUTTONDOWN:
        case WM_MBUTTONDOWN:
        case WM_XBUTTONDOWN:
            state->kind = evCursorClick;
            win32_event_mouse(state, uMsg, wParam, lParam);
            SetCapture(hwnd);
            break;
        case WM_LBUTTONUP:
        case WM_RBUTTONUP:
        case WM_MBUTTONUP:
        case WM_XBUTTONUP:
            state->kind = evCursorRelease;
            win32_event_mouse(state, uMsg, wParam, lParam);
            ReleaseCapture();
            break;

        // Keyboard Window Events
        case WM_KEYDOWN:
        case WM_KEYUP:
            win32_event_keyboard(state, wParam);
            break;

        // Frame Window Events
        case WM_SIZE:
            state->kind = evWindowResize;
            native->info.width = LOWORD(lParam);
            native->info.height = HIWORD(lParam);
            break;
        case WM_CLOSE:
            state->kind = evWindowClose;
            break;

        // Process Event Default
        case WM_PAINT:
            state->kind = evWindowExpose;
        default: goto SEND_DEFAULT;
    }

SEND_EVENT:
    EnterCriticalSection(&native->csWait);
    win32_send_event(native, state);
    LeaveCriticalSection(&native->csWait);
    // Return Nothing
    return 0;

    // Process Default Window Events
SEND_DEFAULT:
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

// ------------------------
// GUI Native Event Pooling
// ------------------------

void nogui_native_pump(nogui_native_t* native) {
    EnterCriticalSection(&native->csWait);
    win32_pump_events(native);
    LeaveCriticalSection(&native->csWait);
}

int nogui_native_poll(nogui_native_t* native) {
    nogui_queue_t* queue = &native->queue;
    nogui_cb_t* cb = queue->first;
    // Copy Callback State to Current State
    if (cb && cb->fn == queue->cb_event.fn) {
        void* data = nogui_cb_data(cb);
        memcpy(&native->state, data, sizeof(nogui_state_t));
    }

    return nogui_queue_poll(queue);
}