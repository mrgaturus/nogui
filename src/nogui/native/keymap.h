#ifndef NOGUI_KEYMAP_H
#define NOGUI_KEYMAP_H

enum nogui_keycode_t;
enum nogui_keymod_t;
typedef unsigned int nogui_keymask_t;
typedef enum nogui_keymod_t nogui_keymod_t;
typedef enum nogui_keycode_t nogui_keycode_t;
// Keyboard & Mouse Keycode String Name
const char* nogui_keycode_name(nogui_keycode_t keycode);

// ------------------------------
// Platform Independent Modifiers
// use with nogui_keymask_t
// ------------------------------

enum nogui_keymod_t {
  Mod_Shift = (1 << 0),
  Mod_Control = (1 << 1),
  Mod_Alt = (1 << 2),
  Mod_AltGr = (1 << 3),
// Keyboard Locked Status
  Mod_Status_Caps = (1 << 4),
  Mod_Status_Numpad  = (1 << 5)
};

// -----------------------------
// Platform Independent Keycodes
// Generated by keymap/keymap.py
// -----------------------------

enum nogui_keycode_t {
  NK_Unknown = 0x0,
  Button_Left = 0x1,
  Button_Right = 0x2,
  Button_Middle = 0x3,
  Button_X1 = 0x4,
  Button_X2 = 0x5,
  NK_Space = 0x20,
  NK_Exclamation = 0x21,
  NK_Quoted = 0x22,
  NK_NumberSign = 0x23,
  NK_Dollar = 0x24,
  NK_Percent = 0x25,
  NK_Ampersand = 0x26,
  NK_Apostrophe = 0x27,
  NK_ParenthesisLeft = 0x28,
  NK_ParenthesisRight = 0x29,
  NK_Asterisk = 0x2a,
  NK_Plus = 0x2b,
  NK_Comma = 0x2c,
  NK_Minus = 0x2d,
  NK_Period = 0x2e,
  NK_Slash = 0x2f,
  NK_0 = 0x30,
  NK_1 = 0x31,
  NK_2 = 0x32,
  NK_3 = 0x33,
  NK_4 = 0x34,
  NK_5 = 0x35,
  NK_6 = 0x36,
  NK_7 = 0x37,
  NK_8 = 0x38,
  NK_9 = 0x39,
  NK_Colon = 0x3a,
  NK_Semicolon = 0x3b,
  NK_Less = 0x3c,
  NK_Equal = 0x3d,
  NK_Greater = 0x3e,
  NK_Question = 0x3f,
  NK_At = 0x40,
  NK_A = 0x41,
  NK_B = 0x42,
  NK_C = 0x43,
  NK_D = 0x44,
  NK_E = 0x45,
  NK_F = 0x46,
  NK_G = 0x47,
  NK_H = 0x48,
  NK_I = 0x49,
  NK_J = 0x4a,
  NK_K = 0x4b,
  NK_L = 0x4c,
  NK_M = 0x4d,
  NK_N = 0x4e,
  NK_O = 0x4f,
  NK_P = 0x50,
  NK_Q = 0x51,
  NK_R = 0x52,
  NK_S = 0x53,
  NK_T = 0x54,
  NK_U = 0x55,
  NK_V = 0x56,
  NK_W = 0x57,
  NK_X = 0x58,
  NK_Y = 0x59,
  NK_Z = 0x5a,
  NK_BracketLeft = 0x5b,
  NK_Backslash = 0x5c,
  NK_BracketRight = 0x5d,
  NK_Underscore = 0x5f,
  NK_Grave = 0x60,
  NK_BraceLeft = 0x7b,
  NK_Bar = 0x7c,
  NK_BraceRight = 0x7d,
  NK_Tilde = 0x7e,
  NK_QuestionDown = 0xbf,
  NK_AltGr = 0xfe03,
  NK_Left_Tab = 0xfe20,
  NK_Backspace = 0xff08,
  NK_Tab = 0xff09,
  NK_Return = 0xff0d,
  NK_Pause = 0xff13,
  NK_Scroll_Lock = 0xff14,
  NK_Sys_Req = 0xff15,
  NK_Escape = 0xff1b,
  NK_Home = 0xff50,
  NK_Left = 0xff51,
  NK_Up = 0xff52,
  NK_Right = 0xff53,
  NK_Down = 0xff54,
  NK_Page_Up = 0xff55,
  NK_Page_Down = 0xff56,
  NK_End = 0xff57,
  NK_Begin = 0xff58,
  NK_Select = 0xff60,
  NK_Print = 0xff61,
  NK_Execute = 0xff62,
  NK_Insert = 0xff63,
  NK_Undo = 0xff65,
  NK_Redo = 0xff66,
  NK_Menu = 0xff67,
  NK_Find = 0xff68,
  NK_Cancel = 0xff69,
  NK_Help = 0xff6a,
  NK_Break = 0xff6b,
  NK_Num_Lock = 0xff7f,
  NKPad_Space = 0xff80,
  NKPad_Tab = 0xff89,
  NKPad_Enter = 0xff8d,
  NKPad_Home = 0xff95,
  NKPad_Left = 0xff96,
  NKPad_Up = 0xff97,
  NKPad_Right = 0xff98,
  NKPad_Down = 0xff99,
  NKPad_Page_Up = 0xff9a,
  NKPad_Page_Down = 0xff9b,
  NKPad_End = 0xff9c,
  NKPad_Begin = 0xff9d,
  NKPad_Insert = 0xff9e,
  NKPad_Delete = 0xff9f,
  NKPad_Multiply = 0xffaa,
  NKPad_Add = 0xffab,
  NKPad_Separator = 0xffac,
  NKPad_Subtract = 0xffad,
  NKPad_Decimal = 0xffae,
  NKPad_Divide = 0xffaf,
  NKPad_0 = 0xffb0,
  NKPad_1 = 0xffb1,
  NKPad_2 = 0xffb2,
  NKPad_3 = 0xffb3,
  NKPad_4 = 0xffb4,
  NKPad_5 = 0xffb5,
  NKPad_6 = 0xffb6,
  NKPad_7 = 0xffb7,
  NKPad_8 = 0xffb8,
  NKPad_9 = 0xffb9,
  NKPad_Equal = 0xffbd,
  NK_F1 = 0xffbe,
  NK_F2 = 0xffbf,
  NK_F3 = 0xffc0,
  NK_F4 = 0xffc1,
  NK_F5 = 0xffc2,
  NK_F6 = 0xffc3,
  NK_F7 = 0xffc4,
  NK_F8 = 0xffc5,
  NK_F9 = 0xffc6,
  NK_F10 = 0xffc7,
  NK_F11 = 0xffc8,
  NK_F12 = 0xffc9,
  NK_Shift_L = 0xffe1,
  NK_Shift_R = 0xffe2,
  NK_Control_L = 0xffe3,
  NK_Control_R = 0xffe4,
  NK_Caps_Lock = 0xffe5,
  NK_Shift_Lock = 0xffe6,
  NK_Meta_L = 0xffe7,
  NK_Meta_R = 0xffe8,
  NK_Alt_L = 0xffe9,
  NK_Alt_R = 0xffea,
  NK_Super_L = 0xffeb,
  NK_Super_R = 0xffec,
  NK_Delete = 0xffff
};

#endif // NOGUI_KEYMAP_H
