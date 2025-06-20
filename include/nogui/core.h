#ifndef NOGUI_CORE
#define NOGUI_CORE
#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    wMOUSE = 1 << 0,
    wKEYBOARD = 1 << 1,
    wIGNORE = 1 << 2,
    wCULL = 1 << 3,
    // Widget Status
    wVISIBLE = 1 << 4,
    wHOVER = 1 << 5,
    wGRAB = 1 << 6,
    wFOCUS = 1 << 7,
    wHOLD = 1 << 8
} widget_flags_t;

typedef enum {
    wkNODE,
    wkLOWTIP,
    wkROOT,
    wkFRAME,
    wkPOPUP,
    wkTOOLTIP
} widget_kind_t;

typedef enum {
    woWIDGET,
    woFORWARD,
    woLAYOUT
} widget_role_t;

// --------------
// Widget Metrics
// --------------

typedef struct {
    int x, y, w, h;
} widget_rect_t;

typedef struct {
    int x, y, w, h;
    int min_w, min_h;
    int max_w, max_h;
} widget_metrics_t;

typedef struct {
    widget_rect_t* levels;
    int count, capacity;
} widget_rectstack_t;

// Widget Rect: Intersections
int widget_rect_inside(widget_rect_t rect, widget_rect_t clip);
int widget_rect_pointInside(widget_rect_t rect, int x, int y);
widget_rect_t widget_rect_intersect(widget_rect_t a, widget_rect_t b);

// Widget Rect: Clipping Stack
widget_rectstack_t widget_rectstact_create();
widget_rect_t widget_rectstack_peek(widget_rectstack_t* stack);
void widget_rectstack_push(widget_rectstack_t* stack, widget_rect_t rect);
void widget_rectstack_pop(widget_rectstack_t* stack);
void widget_rectstack_clear(widget_rectstack_t* stack);
void widget_rectstack_destroy(widget_rectstack_t* stack);

// Widget Metrics: Operations
widget_metrics_t widget_metrics_inset(widget_metrics_t m, int inset);
widget_metrics_t widget_metrics_intersect(widget_metrics_t m, widget_metrics_t m0);
widget_metrics_t widget_metrics_clip(widget_metrics_t m, widget_metrics_t m0);
widget_metrics_t widget_metrics_fit(widget_metrics_t m, widget_metrics_t m0);
widget_metrics_t widget_metrics_hints(widget_metrics_t m, widget_metrics_t m0);
widget_metrics_t widget_metrics_rect(widget_metrics_t m, widget_metrics_t m0);
widget_metrics_t widget_metrics_clamp(widget_metrics_t m);

// --------------------
// Widget Opaque Object
// --------------------

typedef struct {
    void* handle;
    void* event;
    void* update;
    void* layout;
    void* draw;
} widget_vtable_t;

typedef struct widget_opaque_t widget_opaque_t;
typedef widget_opaque_t* widget_t;
struct widget_opaque_t {
    void* type;
    // Widget Nodes
    widget_t parent;
    widget_t next;
    widget_t prev;
    widget_t first;
    widget_t last;
    // Widget Properties
    widget_vtable_t vtable;
    widget_flags_t flags;
    widget_kind_t kind;
    widget_role_t role;
    widget_metrics_t metrics;
    widget_rect_t rect;
};

// Widget Tree Manipulation
void widget_add(widget_t self, widget_t widget);
void widget_attachSwap(widget_t self, widget_t widget);
void widget_attachNext(widget_t self, widget_t widget);
void widget_attachPrev(widget_t self, widget_t widget);
void widget_update(widget_t self);
void widget_detach(widget_t self);

// Widget Tree Manager: Outside
widget_t widget_outside(widget_t self);
int widget_isVisible(widget_t self);
int widget_isFocusable(widget_t self);
// Widget Tree Manager: Point
int widget_pointCheck(widget_t self, int x, int y);
widget_t widget_pointInside(widget_t self, int x, int y);
widget_t widget_pointFind(widget_t self, widget_t outer, int x, int y);
// Widget Tree Manager: Focus
widget_t widget_focusNext(widget_t self);
widget_t widget_focusPrev(widget_t self);

// ----------------------
// Callback Opaque Object
// ----------------------

struct callback_t;
typedef void (*callback_proc_t)(void*, void*);
typedef struct callback_t callback_t;

struct callback_t {
    callback_t* next;
    callback_proc_t fn;
    // Callback Data
    void *self;
    long bytes;
};

typedef struct {
    callback_t* first;
    callback_t* stack;
    callback_t* once;
} callback_queue_t;

// Callback Opaque Object
callback_t* callback_create(int bytes);
int callback_equal(callback_t* a, callback_t* b);
void* callback_data(callback_t* cb);
void callback_call(callback_t* cb);
// Callback Queue Object
void callback_queue_push(callback_queue_t* queue, callback_t* cb);
void callback_queue_relax(callback_queue_t* queue, callback_t* cb);
int callback_queue_poll(callback_queue_t* queue);
void callback_queue_destroy(callback_queue_t* queue);

// -------------------
// State Opaque Object
// -------------------

typedef enum {
    devMOUSE,
    devTOUCH,
    devSTYLUS,
    devERASER,
} event_tool_t;

typedef enum {
    evHOVER_IN,
    evFOCUS_IN,
    evGRAB_IN,
    evHOLD_IN,
    evLAYER_IN,
    // ----- //
    evHOVER_OUT,
    evFOCUS_OUT,
    evGRAB_OUT,
    evHOLD_OUT,
    evLAYER_OUT
} event_handle_t;

typedef enum {
    evDUMMY,
    evRELAXED,
    // Cursor Events
    evCURSOR_MOVE,
    evCURSOR_CLICK,
    evCURSOR_RELEASE,
    // Key Events
    evKEY_DOWN,
    evKEY_UP,
    evFOCUS_NEXT,
    evFOCUS_PREV,
    // Window Events
    evWINDOW_EXPOSE,
    evWINDOW_RESIZE,
    evWINDOW_ENTER,
    evWINDOW_LEAVE,
    evWINDOW_CLOSE
} event_kind_t;

typedef struct {
    event_kind_t kind;
    event_tool_t tool;
    // Cursor State
    int mx, my;
    float px, py;
    float pressure;
    // Keyboard State
    unsigned int key;
    unsigned int mask;
    unsigned int scancode;
    // UTF8 Buffer Input
    int utf8size;
    char* utf8str;
    char utf8char[8];
} event_state_t;

// ---------------------
// Manager Opaque Object
// ---------------------

typedef struct {
    widget_t first;
    widget_t last;
} widget_layer_t;

typedef struct {
    widget_t hover;
    widget_t jump;
    widget_t skip;
} widget_forward_t;

typedef struct {
    widget_forward_t *stack;
    int size, capacity;
    // Hover Forward Status
    int cursor, offset;
    char grab, locked;
} widget_hover_t;

typedef struct {
    void* finalizer;
    event_state_t* state;
    callback_queue_t* queue;
    callback_t cb_event;
    callback_t cb_forward;
    callback_t cb_land;
    // Manager Layers
    widget_layer_t lowtip;
    widget_layer_t root;
    widget_layer_t frame;
    widget_layer_t popup;
    widget_layer_t tooltip;
    // Manager Widget State
    widget_hover_t hover;
    widget_t focus;
    widget_t hold;
} widget_manager_t;

#ifdef __cplusplus
}
#endif
#endif // NOGUI_CORE
