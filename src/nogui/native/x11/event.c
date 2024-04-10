#include "x11.h"
#include <stdlib.h>

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

  // Override Focus Cycle
  if (key == 0xff09)
    state->kind = evNextFocus;
  else if (key == 0xfe20)
    state->kind = evPrevFocus;
  // HACK: Avoid Lookup Raw Numpad Keys
  else if (key < 0xff80 || key > 0xffb9)
    key = XkbKeycodeToKeysym(
      native->display,
      event->xkey.keycode, 
      0, 0
    );

  state->kind = evKeyDown;
  state->scan = key;
  // Translate Key to nogui Keycode
  state->key = x11_keycode_lookup(key);
  state->mask = x11_keymask_lookup(event->xkey.state);
}

static void x11_keypress_release(nogui_state_t* state, XEvent* event) {
  nogui_native_t* native = state->native;
  KeySym key;

  // Handle Key Repeat Properly
  if (XEventsQueued(native->display, QueuedAfterReading)) {
    XEvent peek;
    XPeekEvent(native->display, &peek);
    if (peek.type == KeyPress && 
        peek.xkey.time == event->xkey.time &&
        peek.xkey.keycode == event->xkey.keycode)
      // Skip Event if Repeated
      return;
  }

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
    case ClientMessage:
      // Request Window Close
      if (event->xclient.data.l[0] == native->window_close)
          state->kind = evWindowClose;

      break;
    // -- Cursor Event --
    case GenericEvent:
      // Check XInput2 Event
      if (event->xcookie.extension == native->xi2_opcode) {
        if (XGetEventData(native->display, &event->xcookie)) {
          // Translate XInput2 Event
          x11_xinput2_event(state, event);
          XFreeEventData(native->display, &event->xcookie);
        }
      }

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

// -----------------------
// X11 State Event Polling
// -----------------------

void nogui_state_poll(nogui_state_t* state) {
  // TODO: create a dedicated queue for events and callbacks
  //       for now it uses x11 event pooling because it can
}

int nogui_state_next(nogui_state_t* state) {
  int pending = !! *state->queue;
  // Check Signal Queue
  if (pending) {
    state->kind = evFlush;
    return pending;
  }

  Display* display = state->native->display;
  pending = XPending(display);
  // Process Current Event
  if (pending) {
    XEvent event;
    XNextEvent(display, &event);
    x11_event_translate(state, &event);
  // Check Signal Pending
  } else if ((pending = !! *state->cherry))
    state->kind = evPending;

  return pending;
}
