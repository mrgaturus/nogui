#include "win32.h" // IWYU pragma: keep
#include <stdio.h>
// Include WinTab API
#define NOWTFUNCTIONS
#include <wintab.h>
#define PACKETDATA ( PK_X | PK_Y | PK_NORMAL_PRESSURE | PK_ORIENTATION | PK_ROTATION | PK_STATUS )
#define PACKETMODE 0
#define PACKETSAMPLES 64
#include <pktdef.h>

typedef struct {
  HINSTANCE module;
  HCTX ctx;
  HWND hwnd;
  // Device Info
  AXIS axPressure;
  AXIS axOrientation;
  AXIS axDVC_X;
  AXIS axDVC_Y;
  LOGCONTEXTA lc;
  // Device Status
  BOOL enabled;
  BOOL active;
  BOOL proximity;
  // Packet Guard
  PACKET peek;
} win32_wintab_t;

// --------------------
// Win32 Wintab Context
// --------------------

typedef BOOL (API * WTINFO)(UINT, UINT, LPVOID);
typedef HCTX (API * WTOPEN)(HWND, PLOGCONTEXT, BOOL);
typedef BOOL (API * WTCLOSE)(HCTX);
typedef BOOL (API * WTPACKET)(HCTX, UINT, LPVOID);
typedef int (API * WTQUEUESIZEGET)(HCTX);
typedef BOOL (API * WTQUEUESIZESET)(HCTX, int);
typedef BOOL (API * WTENABLE)(HCTX, BOOL);
typedef BOOL (API * WTSET)(HCTX, LPLOGCONTEXTA);

// WinTab API Functions
static WTINFO WTInfo;
static WTOPEN WTOpen;
static WTCLOSE WTClose;
static WTPACKET WTPacket;
static WTQUEUESIZEGET WTQueueSizeGet;
static WTQUEUESIZESET WTQueueSizeSet;
static WTENABLE WTEnable;
static WTSET WTSet;
// WinTab API Structure
static win32_wintab_t wintab;

// -------------------------------
// Win32 Wintab Coordinate Mapping
// -------------------------------

static void win32_wintab_lc(HWND hwnd, LOGCONTEXTA* lc) {
  memset(lc, 0, sizeof(LOGCONTEXTA));
  lc->lcOptions = CXO_SYSTEM;
  // Load WinTab LOGCONTEXT
  WTInfo(WTI_DEFSYSCTX, 0, lc);
  sprintf(lc->lcName, "nogui %p", hwnd);
  // Reconfigure Packet Data
  lc->lcOptions |= CXO_MESSAGES;
  lc->lcPktData = PACKETDATA;
  lc->lcPktMode = PACKETMODE;
  lc->lcMoveMask = PACKETDATA;
  // Handle Coordinates Manually
  lc->lcOutOrgX = lc->lcInOrgX;
  lc->lcOutOrgY = lc->lcInOrgY;
  lc->lcOutExtX = lc->lcInExtX;
  lc->lcOutExtY = lc->lcInExtY;

  //log_info("Input Origin %lo %lo", lc->lcInOrgX, lc->lcInOrgY);
  //log_info("Input Extremum %lo %lo", lc->lcInExtX, lc->lcInExtY);
  //log_info("Output Origin %lo %lo", lc->lcOutOrgX, lc->lcOutOrgY);
  //log_info("Output Extremum %lo %lo\n", lc->lcOutExtX, lc->lcOutExtY);
  // Configure for Raw Coordinates
  //log_info("Sys Input Origin %lo %lo", lc->lcSysOrgX, lc->lcSysOrgY);
  //log_info("Sys Input Extremum %lo %lo", lc->lcSysExtX, lc->lcSysExtY);
  //log_info("Sys Output Origin %lo %lo", lc->lcSysOrgX, lc->lcSysOrgY);
  //log_info("Sys Output Extremum %lo %lo", lc->lcSysExtX, lc->lcSysExtY);
}

// --------------------
// Win32 Wintab Context
// --------------------

void win32_wintab_init(HWND hwnd) {
  HINSTANCE module = LoadLibrary("wintab32");
  if (!module) return;

  // Initialize WinTab Functions
  WTInfo = (WTINFO) GetProcAddress(module, "WTInfoA");
  WTOpen = (WTOPEN) GetProcAddress(module, "WTOpenA");
  WTClose = (WTCLOSE) GetProcAddress(module, "WTClose");
  WTPacket = (WTPACKET) GetProcAddress(module, "WTPacket");
  WTQueueSizeGet = (WTQUEUESIZEGET) GetProcAddress(module, "WTQueueSizeGet");
  WTQueueSizeSet = (WTQUEUESIZESET) GetProcAddress(module, "WTQueueSizeSet");
  WTEnable = (WTENABLE) GetProcAddress(module, "WTEnable");
  WTSet = (WTSET) GetProcAddress(module, "WTSetA");

  // Initialize Wintab Driver
  win32_wintab_lc(hwnd, &wintab.lc);
  HCTX ctx = WTOpen(hwnd, &wintab.lc, FALSE);
  if (!ctx) {
    log_warning("wintab driver: not initialized");
    return;
  }

  // Configure Queue Size
  int size0 = WTQueueSizeGet(ctx);
  if (!WTQueueSizeSet(ctx, PACKETSAMPLES))
    if(!WTQueueSizeSet(ctx, size0))
      log_warning("wintab driver: queue not sized");

  // Initialize Wintab Instance
  wintab.module = module;
  wintab.ctx = ctx;
  wintab.hwnd = hwnd;
  // Initialize WinTab Device Properties
  unsigned int device = WTI_DEVICES + wintab.lc.lcDevice;
  WTInfo(device, DVC_NPRESSURE, &wintab.axPressure);
  WTInfo(device, DVC_ORIENTATION, &wintab.axOrientation);
}

void win32_wintab_destroy(HWND hwnd) {
  WTClose(wintab.ctx);
  FreeLibrary(wintab.module);
}

// --------------------------------------------
// Win32 WinTab to Window Client Coordinates
// blender/intern/ghost/intern/GHOST_Wintab.cpp
// --------------------------------------------

static float win32_wintab_coord(int a, int in0, int in1, int out0, int out1) {
  int in2 = (in1 < 0) ? -in1 : in1;
  int out2 = (out1 < 0) ? -out1 : out1;
  // Adjust Origin
  a = a - in0;
  if ((in1 < 0) != (out1 < 0))
    a = in2 - a;
  // Scale Coordinate
  float o = (float) (a * out2) / in2;
  return o + (float) out0;
}

// ---------------------
// Win32 WinTab Messages
// ---------------------

BOOL win32_wintab_active(WPARAM wParam, LPARAM lParam) {
  return wintab.ctx && wintab.enabled && wintab.proximity && wintab.active;
}

BOOL win32_wintab_packet(nogui_state_t* state, WPARAM wParam, LPARAM lParam) {
  POINT offset = { 0 }; ClientToScreen(wintab.hwnd, &offset);
  LPLOGCONTEXTA lc = &wintab.lc;
  // Lookup WinTab Packet
  PACKET packet = wintab.peek;
  if (WTPacket(wintab.ctx, wParam, &packet)) {
    float pressure = (float) packet.pkNormalPressure / (float) wintab.axPressure.axMax;
    float x = win32_wintab_coord(packet.pkX, lc->lcInOrgX, lc->lcInExtX, lc->lcSysOrgX, lc->lcSysExtX);
    float y = win32_wintab_coord(packet.pkY, lc->lcInOrgY, lc->lcInExtY, lc->lcSysOrgY, -lc->lcSysExtY);
    nogui_tool_t tool = (packet.pkStatus & TPS_INVERT) ? devEraser : devStylus;

    // Replace State Attributes
    state->kind = evCursorMove;
    state->tool = tool;
    state->px = x - (float) offset.x;
    state->py = y - (float) offset.y;
    state->mx = (int) state->px;
    state->my = (int) state->py;
    state->pressure = pressure;
  }

  // Avoid Flooding Same Exact Packet - X11 Behaviour
  BOOL pass = memcmp(&packet, &wintab.peek, sizeof(PACKET));
  wintab.peek = packet;
  // Return Check
  return pass;
}

// -------------------
// Win32 WinTab Status
// -------------------

void win32_wintab_status(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
  if (!wintab.ctx) return;
  BOOL enabled = wintab.enabled;

  switch (uMsg) {
    case WM_ACTIVATE:
      wintab.active = wParam != WA_INACTIVE;
      break;
    // Tablet Device Proximityc
    case WT_PROXIMITY:
      wintab.proximity = !! LOWORD(lParam);
      break;
    // Mouse Enter Leave
    case WM_MOUSELEAVE:
      wintab.enabled = FALSE;
      break;
    case WM_MOUSEMOVE:
      wintab.enabled = TRUE;
      // Track Mouse Leave
      TRACKMOUSEEVENT tme;
      tme.cbSize = sizeof(TRACKMOUSEEVENT);
      tme.dwFlags = TME_LEAVE;
      tme.hwndTrack = hwnd;
      TrackMouseEvent(&tme);
      break;
    // Remap WinTab Region
    case WM_DISPLAYCHANGE:
      win32_wintab_lc(hwnd, &wintab.lc);
      WTSet(wintab.ctx, &wintab.lc);
      break;
  }

  // React to Enabled Changes
  if (enabled != wintab.enabled) {
    if (WTEnable(wintab.ctx, wintab.enabled) == FALSE)
      log_warning("wintab driver: failed change status");
  }
}
