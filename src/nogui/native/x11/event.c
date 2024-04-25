#include "x11.h"
#include <stdlib.h>
#include <string.h>

// ---------------------
// X11 Keyboard Keycodes
// ---------------------

extern	KeySym XkbKeycodeToKeysym(
		Display *	/* display */,
		KeyCode 	/* kc */,
		int 		/* group */,
		int		/* level */
);

static void x11_keypress_utf8buffer(nogui_state_t* state, int cap) {
  if (state->utf8str)
    free(state->utf8str);
  // Allocate New Buffer With New Capacity
  state->utf8str = malloc(cap + 1);
  state->utf8cap = cap + 1;
}

// -------------------
// X11 Keyboard Events
// -------------------

static void x11_keypress_event(nogui_state_t* state, XEvent* event) {
  nogui_native_t* native = state->native;
  KeySym key;

  // Lookup UTF8 String or Keysym
  state->utf8size = Xutf8LookupString(
    native->xic, &event->xkey,
    state->utf8str, state->utf8cap - 1,
    &key, &state->utf8state);

  // Expand Buffer if is Not Enough
  if (state->utf8state == XBufferOverflow) {
    x11_keypress_utf8buffer(state, state->utf8size);
    // Try Lookup UTF8 String Again
    state->utf8size = Xutf8LookupString(
      native->xic, &event->xkey,
      state->utf8str, state->utf8cap - 1,
      &key, &state->utf8state);
  }

  // Add null-terminated to UTF8 Buffer
  state->utf8str[state->utf8size] = '\0';

  state->kind = evKeyDown;
  // Override Focus Cycle
  if (key == 0xff09)
    state->kind = evFocusNext;
  else if (key == 0xfe20)
    state->kind = evFocusPrev;
  // HACK: Avoid Lookup Raw Numpad Keys
  else if (key < 0xff80 || key > 0xffb9)
    key = XkbKeycodeToKeysym(
      native->display,
      event->xkey.keycode, 
      0, 0
    );

  state->scan = key;
  // Translate Key to nogui Keycode
  state->key = x11_keycode_lookup(key);
  state->mask = x11_keymask_lookup(event->xkey.state);
}

static void x11_keypress_release(nogui_state_t* state, XEvent* event) {
  nogui_native_t* native = state->native;
  KeySym key;

  unsigned int mods = event->xkey.state;
  KeyCode code = event->xkey.keycode;
  // Lookup True Released Key
  key = XkbKeycodeToKeysym(
    native->display, code, 0, 0);

  // HACK: Handle Left Tabulation
  if (key == 0xff09 && (mods & ShiftMask))
    key = 0xfe20;
  // HACK: Handle Numpad Keys
  else if (key >= 0xff80 && key <= 0xffb9) {
    int check = mods & (Mod2Mask | ShiftMask);
    // Num Lock enabled and Shift not pressed
    key = XkbKeycodeToKeysym(
      native->display, code, 0, 
      mods == Mod2Mask);
  }

  state->kind = evKeyUp;
  state->scan = key;
  // Translate Keys to nogui
  state->key = x11_keycode_lookup(key);
  state->mask = x11_keymask_lookup(mods);
}

// ---------------------
// X11 Event Translation
// ---------------------

static void x11_event_translate(nogui_state_t* state, XEvent* event) {
  nogui_native_t* native = state->native;
  state->kind = evUnknown;
  // Skip Taken Events
  if (XFilterEvent(event, 0) != 0)
    return;

  switch (event->type) {
    case Expose:
      state->kind = evWindowExpose;
      break;
    case ConfigureNotify:
      state->kind = evWindowResize;

      // Reflect Window Size
      XConfigureEvent* config = &event->xconfigure;
      nogui_info_t* info = &native->info;
      // Check Window Change
      int w = config->width;
      int h = config->height;

      // Check if Actually Resized
      if (info->width == w && info->height == h)
        state->kind = evUnknown;
      // Reflect Window Size
      info->width = w;
      info->height = h;

      break;

    // -- Window Close Event --
    case ClientMessage:
      // Request Window Close
      if (event->xclient.data.l[0] == native->window_close)
          state->kind = evWindowClose;
      break;

    // -- XInput2 Event --
    case GenericEvent:
      if (event->xcookie.data)
          x11_xinput2_event(state, event);
      break;

    // -- Keyboard Events --
    case KeyPress: 
      x11_keypress_event(state, event);
      break;
    case KeyRelease:
      x11_keypress_release(state, event);
      break;
  }
}

// ----------------------
// X11 Native Event Queue
// ----------------------

void nogui_native_pump(nogui_native_t* native) {
  Display* display = native->display;
  nogui_queue_t* queue = &native->queue;

  XEvent event;
  const long size = sizeof(event);
  // Pump X11 Events
  while (XPending(display)) {
    XNextEvent(display, &event);

    // Prepare XInput2 Generic Event
    if (event.type == GenericEvent) {
      event.xcookie.data = NULL;
      // Retreive XInput2 Cookie Data
      if (event.xcookie.extension == native->xi2_opcode)
        XGetEventData(native->display, &event.xcookie);
    // Handle Key Repeat Properly
    } else if (event.type == KeyRelease) {
      if (XEventsQueued(native->display, QueuedAfterReading)) {
        XEvent peek;
        XPeekEvent(native->display, &peek);
        // Avoid Instant KeyRelease Events
        if (peek.type == KeyPress && 
            peek.xkey.time == event.xkey.time &&
            peek.xkey.keycode == event.xkey.keycode)
          // Skip Event if Repeated
          return;
      }
    }

    // Prepare Created Callback
    nogui_cb_t* c = nogui_cb_create(size);
    c->fn = queue->cb_event.fn;
    c->self = queue->cb_event.self;
    // Copy XEvent to Callback
    void* data = nogui_cb_data(c);
    memcpy(data, &event, size);

    // Push Callback to Queue
    nogui_queue_push(queue, c);
  }
}

int nogui_native_poll(nogui_native_t* native) {
  nogui_queue_t* queue = &native->queue;
  nogui_cb_t* cb = queue->first;
  
  // Translate XEvent to nogui State
  if (cb && cb->fn == queue->cb_event.fn) {
    XEvent* event = (XEvent*) nogui_cb_data(cb);
    x11_event_translate(&native->state, event);

    // Destroy XInput2 Generic Event
    if (event->type == GenericEvent && event->xcookie.data)
      XFreeEventData(native->display, &event->xcookie);
  }

  // Dispatch Current Callback
  return nogui_queue_poll(queue);
}
