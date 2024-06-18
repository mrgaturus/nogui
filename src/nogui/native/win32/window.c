#include "win32.h" // IWYU pragma: keep
#include <GL/gl.h>
#include <GL/wgl.h>

// ------------------
// WGL Initialization
// ------------------

PFNWGLCREATECONTEXTATTRIBSARBPROC wglCreateContextAttribsARB;
PFNWGLCHOOSEPIXELFORMATARBPROC wglChoosePixelFormatARB;
static void* modernGetProcAddress(const char *name)
{
  void *p = (void *)wglGetProcAddress(name);
  if(p == 0 ||
    (p == (void*)0x1) || (p == (void*)0x2) || (p == (void*)0x3) ||
    (p == (void*)-1) )
  {
    HMODULE module = LoadLibraryA("opengl32.dll");
    p = (void *)GetProcAddress(module, name);
  }

  return p;
}

static BOOL win32_opengl_stage0(HWND hwnd) {
    const PIXELFORMATDESCRIPTOR pfd = {
        .nSize = sizeof(PIXELFORMATDESCRIPTOR),
        .nVersion = 1,
        .dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        .iPixelType = PFD_TYPE_RGBA,
        .cColorBits = 32,
        .cAlphaBits = 8,
        .iLayerType = PFD_MAIN_PLANE,
        .cDepthBits = 24,
        .cStencilBits = 8,
    };

    HDC hdc0 = GetDC(hwnd);
    int pixelFormat = ChoosePixelFormat(hdc0, &pfd);
    SetPixelFormat(hdc0, pixelFormat, &pfd);
    // Configure OpenGL Device Context
    HGLRC hglrc0 = wglCreateContext(hdc0);
    BOOL status = wglMakeCurrent(hdc0, hglrc0);

    // Modern OpenGL Loader Function Pointers
    wglCreateContextAttribsARB = (PFNWGLCREATECONTEXTATTRIBSARBPROC) wglGetProcAddress("wglCreateContextAttribsARB");
    wglChoosePixelFormatARB = (PFNWGLCHOOSEPIXELFORMATARBPROC) wglGetProcAddress("wglChoosePixelFormatARB");

    wglMakeCurrent(hdc0, 0);
    wglDeleteContext(hglrc0);
    ReleaseDC(hwnd, hdc0);
    // Return Created Context
    return status;
}

static BOOL win32_opengl_stage1(HWND hwnd, HDC* hdc, HGLRC* hglrc) {
    const int pfd_attribs[] = {
        WGL_DRAW_TO_WINDOW_ARB,     GL_TRUE,
        WGL_SUPPORT_OPENGL_ARB,     GL_TRUE,
        WGL_DOUBLE_BUFFER_ARB,      GL_TRUE,
        WGL_ACCELERATION_ARB,       WGL_FULL_ACCELERATION_ARB,
        WGL_PIXEL_TYPE_ARB,         WGL_TYPE_RGBA_ARB,
        WGL_COLOR_BITS_ARB,         32,
        WGL_DEPTH_BITS_ARB,         24,
        WGL_STENCIL_BITS_ARB,       8,
        0
    };

    const int context_attribs[] = {
        WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
        WGL_CONTEXT_MINOR_VERSION_ARB, 3,
        WGL_CONTEXT_PROFILE_MASK_ARB,  WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    };

    HDC hdc0 = GetDC(hwnd);
    int pixel_format; UINT num_formats;
    wglChoosePixelFormatARB(hdc0, pfd_attribs, 0, 1, &pixel_format, &num_formats);

    PIXELFORMATDESCRIPTOR pfd;
    DescribePixelFormat(hdc0, pixel_format, sizeof(pfd), &pfd);
    SetPixelFormat(hdc0, pixel_format, &pfd);

    // Configure OpenGL Device Context
    HGLRC hglrc0 = wglCreateContextAttribsARB(hdc0, 0, context_attribs);
    BOOL status = wglMakeCurrent(hdc0, hglrc0);

    *hdc = hdc0;
    *hglrc = hglrc0;
    return status;
}

// ---------------------------
// Win32 Window Initialization
// ---------------------------

static HWND win32_create_window(nogui_native_t* native) {
    const char CLASS_NAME[] = "nogui#app";
    const char TITLE_NAME[] = "";
    // Lookup Current Instance Module
    HINSTANCE hInstance;
    GetModuleHandleEx(
        GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        (LPCSTR) &win32_create_window, &hInstance
    );

    // Define Window Class
    WNDCLASS wc = { };
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = NULL;
    // Register the Window class
    RegisterClass(&wc);

    // Create the window
    HWND hwnd = CreateWindowEx(
        0,                   // Optional window styles
        CLASS_NAME,          // Window class
        TITLE_NAME,          // Window title
        WS_OVERLAPPEDWINDOW, // Window style

        // Size and position
        CW_USEDEFAULT, CW_USEDEFAULT,
        native->info.width,
        native->info.height,

        NULL,           // Parent window
        NULL,           // Menu
        hInstance,      // Instance handle
        (LPVOID) native // Window Parameter
    );

    return hwnd;
}

// -------------------
// Win32 Window Thread
// -------------------

static int win32_app_message(HWND hwnd, MSG* msg) {
    LPARAM lParam = msg->lParam;

    switch (msg->message) {
        case NOGUI_DESTROY:
            PostQuitMessage(0);
            return 0;
        case NOGUI_CURSOR:
            SetClassLongPtr(hwnd, GCLP_HCURSOR, (LONG_PTR) lParam);
            SetCursor((HCURSOR) lParam);
            return 0;
        case NOGUI_TITLE: {
            LPCSTR str = (LPCSTR) lParam;
            SetWindowText(hwnd, str);
            free((void*) str);
            return 0;
        }
    }

    // Continue HWND
    return 1;
}

DWORD WINAPI ThreadProc(LPVOID lpParam) {
    nogui_native_t* native = (nogui_native_t*) lpParam;
    HWND hwnd = win32_create_window(native);
    win32_wintab_init(hwnd);

    BOOL staged_gl =
        win32_opengl_stage0(hwnd) &&
        win32_opengl_stage1(hwnd, &native->hdc, &native->hglrc);
    if (!staged_gl) {
        MessageBox(hwnd, "OpenGL 3.3 not found on this system", "Failed Initialize", MB_OK | MB_ICONERROR);
        exit(1);
    }

    // HWND Ready for Execute
    wglMakeCurrent(NULL, NULL);
    SetEvent(native->evWait);

    // Wait for HWND Execution
    WaitForSingleObject(native->evWait, INFINITE);
    ShowWindow(hwnd, SW_SHOWDEFAULT);
    // Watch HWND Messages
    MSG msg = { 0 };
    while (GetMessage(&msg, NULL, 0, 0)) {
        if (win32_app_message(hwnd, &msg) == 0)
            continue;

        // Dispatch HWND Message
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    // Destroy Win32 WGL
    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(native->hglrc);
    ReleaseDC(hwnd, native->hdc);
    // Destroy Win32 Window
    win32_wintab_destroy(hwnd);
    DestroyWindow(hwnd);

    // Destroy Thread
    return 0;
}

// ---------------------------
// Win32 Native Initialization
// ---------------------------

nogui_native_t* nogui_native_init(int w, int h) {
    nogui_native_t* native = malloc(sizeof(nogui_native_t));
    // Initialize Native Info
    native->info.width = w;
    native->info.height = h;
    native->info.glProc = modernGetProcAddress;
    // Create Thread Critical Sections
    InitializeCriticalSection(&native->csWait);
    native->evWait = CreateEvent(NULL, FALSE, FALSE, NULL);

    // Create Win32 Thread
    HANDLE thrd = CreateThread(            
        NULL,        // default security attributes
        0,           // default stack size
        ThreadProc,  // thread function
        native,      // native function arguments
        0,           // default creation flags
        &native->id  // receive thread identifier
    );

    // Wait HWND Thread Initialized
    WaitForSingleObject(native->evWait, INFINITE);
    wglMakeCurrent(native->hdc, native->hglrc);
    native->thrd = thrd;

    // Initialize Native Title
    native->info.title = calloc(1, 1);
    native->info.id = calloc(1, 1);
    native->info.name = calloc(1, 1);
    // Initialize Native Queue
    native->csState = (nogui_state_t) {};
    native->csQueue = (nogui_queue_t) {};
    native->queue = (nogui_queue_t) {};
    // Initialize Native State
    native->state.native = native;
    native->csState.native = native;

    return native;
}

int nogui_native_open(nogui_native_t* native) {
    nogui_queue_t* queue = &native->queue;
    nogui_queue_t* queue0 = &native->csQueue;
    queue0->cb_event = queue->cb_event;

    // Continue HWND Thread
    SetEvent(native->evWait);
    return TRUE;
}

void nogui_native_frame(nogui_native_t* native) {
    SwapBuffers(native->hdc);
}

void nogui_native_destroy(nogui_native_t* native) {
    PostThreadMessage(native->id, NOGUI_DESTROY, 0, 0);
    WaitForSingleObject(native->thrd, INFINITE);

    // Deallocate Threading
    CloseHandle(native->thrd);
    CloseHandle(native->evWait);
    DeleteCriticalSection(&native->csWait);

    // Dealloc Native Title
    free(native->info.title);
    free(native->info.id);
    free(native->info.name);

    // Dealloc Native Platform
    nogui_queue_destroy(&native->queue);
    free(native);
}

// -----------------------------
// Win32 Native Objects Pointers
// -----------------------------

nogui_info_t* nogui_native_info(nogui_native_t* native) {
    return &native->info;
}

nogui_queue_t* nogui_native_queue(nogui_native_t* native) {
    return &native->queue;
}

nogui_state_t* nogui_native_state(nogui_native_t* native) {
    return &native->state;
}
