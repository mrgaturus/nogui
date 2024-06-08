#include "x11.h"
#include <X11/extensions/XInput2.h>
// Device Initialization
#include <ctype.h>
#include <string.h>
#include <stdlib.h>
// XInput2 Tablet
#define NO_PRESSURE ~0
#define MASTER_POINTER 2

// -------------------
// XInput2 Device Tool
// -------------------

static int name_suffix(char* name, const char* suffix) {
  int l0 = strlen(name) - 1;
  int l1 = strlen(suffix) - 1;

  if (l0 < l1)
    return 0;

  while (l1 >= 0) {
    if (tolower(name[l0]) != tolower(suffix[l1]))
      break;

    // Next Char
    l0--;
    l1--;
  }

  return l1 < 0;
}

static nogui_tool_t x11_xinput2_tool(char* name) {
  if (name_suffix(name, "virtual core"))
    return devMouse;
  else if (name_suffix(name, "stylus") || name_suffix(name, "pen"))
    return devStylus;
  else if (name_suffix(name, "eraser"))
    return devEraser;
  // Otherwise Fallback to Mouse
  else return devMouse;
}

// -------------------------
// XInput2 Device Initialize
// -------------------------

static xi2_device_t* x11_xinput2_device(XIDeviceInfo* info, Atom press) {
  xi2_device_t* dev = malloc(sizeof(xi2_device_t));

  dev->id = info->deviceid;
  dev->number = NO_PRESSURE;
  XIAnyClassInfo** classes = info->classes;

  // Lookup Pressure Information
  for (int i = 0; i < info->num_classes; i++) {
    XIAnyClassInfo* dev_class = classes[i];
    // Check Valuator Information
    if (dev_class->type == XIValuatorClass) {
      XIValuatorClassInfo* valuator = (XIValuatorClassInfo*) dev_class;
      // Store Pressure Information
      // TODO: store tilt information
      if (valuator->label == press) {
        dev->number = valuator->number;
        // Store Valuator Range
        dev->min = valuator->min;
        dev->max = valuator->max;
      }
    }
  }

  // Indentify Device Tool Kind
  dev->tool = x11_xinput2_tool(info->name);
  // Return Device
  return dev;
}

static void x11_xinput2_devices(nogui_native_t* native) {
  Display* display = native->display;
  int count = 0;

  // TODO: store tilt information
  Atom press = XInternAtom(display, "Abs Pressure", 0);
  XIDeviceInfo* list = XIQueryDevice(display, XIAllDevices, &count);

  native->xi2_devices = NULL;
  // Register XInput2 Devices
  for (int i = 0; i < count; i++) {
    XIDeviceInfo* info = &list[i];
    if (info->use != XISlavePointer)
      continue;

    xi2_device_t* dev = x11_xinput2_device(info, press);
    // Add Device to Linked List
    dev->next = native->xi2_devices;
    native->xi2_devices = dev;
  }

  // Free Device Info
  XIFreeDeviceInfo(list);
}

// ----------------------------
// XInput2 Extension Initialize
// ----------------------------

static void x11_xinput2_enable(nogui_native_t* native) {
  XIEventMask em;
  unsigned char mask;
  // Select Master Pointer Group
  em.deviceid = MASTER_POINTER;
  // Select XI2 Event Masks
  em.mask_len = 1;
  em.mask = &mask;

  // Select XInput2 Masks
  XISetMask(&mask, XI_ButtonPress);
  XISetMask(&mask, XI_ButtonRelease);
  XISetMask(&mask, XI_Motion);

  // Bind to Current Display and Window
  XISelectEvents(
    native->display, 
    native->XID, 
    &em, 1
  );
}

void x11_xinput2_init(nogui_native_t* native) {
  int check = 0;
  int major, minor;

  // Check if XInput is present
  check = XQueryExtension(
    native->display, 
    "XInputExtension",
    &native->xi2_opcode,
    &check, &check
  );

  if (!check)
    goto XINPUT_NOT_FOUND;

  // Check if is XInput2
  major = 2; minor = 0;
  check = XIQueryVersion(
    native->display, &major, &minor);

  if (check == BadRequest) {
    XINPUT_NOT_FOUND:
      log_error("XInput2 extension not supported");
  }

  // Enable XInput2 Devices
  x11_xinput2_devices(native);
  x11_xinput2_enable(native);
}

// -------------------
// XInput2 Event State
// -------------------

static xi2_device_t* x11_xinput2_find(xi2_device_t* list, int id) {
  xi2_device_t* found = list;
  // Find XInput2 Device by ID
  while (found) {
    if (found->id == id)
      break;
    // Next Device
    found = found->next;
  }

  return found;
}

void x11_xinput2_event(nogui_state_t* state, XEvent* event) {
  XIDeviceEvent* ev = event->xcookie.data;

  // Process Event Kind
  switch (ev->evtype) {
    case XI_Motion:
      state->kind = evCursorMove;
      break;
    case XI_ButtonPress:
      state->kind = evCursorClick;
      state->key = ev->detail;
      break;
    case XI_ButtonRelease:
      state->kind = evCursorRelease;
      state->key = ev->detail;
      break;
    // Window Enter Leave
    case XI_Enter:
      state->kind = evWindowEnter;
      return;
    case XI_Leave:
      state->kind = evWindowLeave;
      return;
    // Invalid Event
    default:
      state->kind = evUnknown;
      return;
  }

  // Process Event Coordinates
  state->px = ev->event_x;
  state->py = ev->event_y;
  state->mx = (int) state->px;
  state->my = (int) state->py;
  // Process Keyboard Event Modifiers
  state->mask = x11_keymask_lookup(ev->mods.base);

  // Find XInput2 Source Device
  xi2_device_t* dev = state->native->xi2_devices;
  dev = x11_xinput2_find(dev, ev->sourceid);

  if (dev && dev->number > NO_PRESSURE) {
    unsigned char* mask = ev->valuators.mask;
    // Return Tool Kind
    state->tool = dev->tool;

    // Use Last Pressure to Avoid Discontinues
    if (XIMaskIsSet(mask, dev->number) == 0) {
      state->pressure = dev->last;
      return;
    }

    int value = 0;
    // Find Raw Pressure Valuator
    for (int i = 0; i < dev->number; i++)
      value += XIMaskIsSet(mask, i) != 0;
    // Normalize Raw Pressure
    double press = ev->valuators.values[value];
    press = (press - dev->min) / (dev->max - dev->min);

    // Return Pressure
    dev->last = press;
    state->pressure = press;
  }
}

// ----------------------
// XInput2 Device Destroy
// ----------------------

void x11_xinput2_destroy(nogui_native_t* native) {
  // Destroy Devices
  xi2_device_t* dev = native->xi2_devices;
  while (dev) {
    xi2_device_t* prev = dev;
    dev = dev->next;
    // Dealloc Device
    free(prev);
  }
}
