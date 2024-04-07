#include "x11.h"
#include <stdlib.h>

// --------------------------
// X11 State Event Processing
// --------------------------

static void x11_event_utf8buffer(nogui_state_t* state, int cap) {
  if (state->utf8str)
    free(state->utf8str);
  // Allocate New Buffer With New Capacity
  state->utf8str = malloc(cap);
  state->utf8cap = cap;
}

static void x11_event_translate(nogui_state_t* state, XEvent* event) {
  nogui_native_t* native = state->native;
  state->kind = evInvalid;
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
      info->width = config->width;
      info->height = config->height;

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
      // Lookup UTF8 String or Char
      XKeyPressedEvent* press = (XKeyPressedEvent*) &event;
      state->utf8size = Xutf8LookupString(
        native->xic, press,
        state->utf8str, state->utf8cap, 
        &state->key, &state->utf8state);

      // Expand Buffer if is Not Enough
      if (state->utf8state == XBufferOverflow) {
        x11_event_utf8buffer(state, state->utf8size);
        // Try Lookup UTF8 String Again
        state->utf8size = Xutf8LookupString(
          native->xic, press,
          state->utf8str, state->utf8cap, 
          &state->key, &state->utf8state);
      }

      // Override Focus Cycle
      if (state->key == 0xff09)
        state->kind = evNextFocus;
      else if (state->key == 0xfe20)
        state->kind = evPrevFocus;

      break;
    case KeyRelease:
      state->kind = evKeyUp;
      state->mods = event->xkey.state;

      // Handle Key Repeat Properly
      if (XEventsQueued(native->display, QueuedAfterReading)) {
        XEvent peek;
        XPeekEvent(native->display, &peek);
        if (peek.type == KeyPress && 
            peek.xkey.time == event->xkey.time &&
            peek.xkey.keycode == event->xkey.keycode)
          // Skip Event if Repeated
          state->kind = evInvalid;
          return;
      }

      unsigned int mods = state->mods;
      mods = (mods & ShiftMask) | (mods & LockMask);
      state->key = XLookupKeysym(&event->xkey, mods);

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
  // Check Queue Flushing
  int pending = nogui_state_flush(state);
  if (pending) return pending;

  Display* display = state->native->display;
  pending = XPending(display);
  // Process Current Event
  if (pending) {
    XEvent event;
    XNextEvent(display, &event);
    nogui_state_translate(state, &event);
  }

  return pending;
}