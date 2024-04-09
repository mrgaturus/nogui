#include "x11.h"
#include <stdlib.h>

// -------------------
// X11 State Event Key
// -------------------

extern	KeySym XkbKeycodeToKeysym(
		Display *	/* display */,
		KeyCode 	/* kc */,
		int 		/* group */,
		int		/* level */
);

static void x11_event_utf8buffer(nogui_state_t* state, int cap) {
  if (state->utf8str)
    free(state->utf8str);
  // Allocate New Buffer With New Capacity
  state->utf8str = malloc(cap + 1);
  state->utf8cap = cap + 1;
}

// --------------------------
// X11 State Event Processing
// --------------------------

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
    // TODO: create a first class IME
    case KeyPress:
      state->kind = evKeyDown;
      state->mods = event->xkey.state;

      // Lookup UTF8 String or Keysym
      state->utf8size = Xutf8LookupString(
        native->xic, &event->xkey,
        state->utf8str, state->utf8cap - 1,
        &state->key, &state->utf8state);

      // Expand Buffer if is Not Enough
      if (state->utf8state == XBufferOverflow) {
        x11_event_utf8buffer(state, state->utf8size);
        // Try Lookup UTF8 String Again
        state->utf8size = Xutf8LookupString(
          native->xic, &event->xkey,
          state->utf8str, state->utf8cap - 1,
          &state->key, &state->utf8state);
      }

      // Add null-terminated to UTF8 Buffer
      state->utf8str[state->utf8size] = '\0';

      // Override Focus Cycle
      if (state->key == 0xff09)
        state->kind = evNextFocus;
      else if (state->key == 0xfe20)
        state->kind = evPrevFocus;
      // HACK: Handle Numpad Keys thanks to Xutf8LookupString Keysym
      else if (state->key < 0xff80 || state->key > 0xffb9)
        state->key = XkbKeycodeToKeysym(
          native->display,
          event->xkey.keycode, 
          0, 0
        );

      break;
    case KeyRelease:
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
      KeySym key = XkbKeycodeToKeysym(
        native->display, code, 0, 0);

      // HACK: Handle Left Tabulation
      if (key == 0xff09 && (mods & ShiftMask))
        key = 0xfe20;
      // HACK: Handle Numpad Keys
      else if (key >= 0xff80 && key <= 0xffb9)
        key = XkbKeycodeToKeysym(
          native->display, code, 0, 
          (mods & Mod2Mask) != 0);

      state->kind = evKeyUp;
      state->key = key;
      state->mods = mods;

      break;
  }
}

// -----------------------
// X11 State Event Polling
// -----------------------

void nogui_state_poll(nogui_state_t* state) {
  // X11 Doesn't need Manual Pooling
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
  } else if (pending = !! *state->cherry)
    state->kind = evPending;

  return pending;
}
