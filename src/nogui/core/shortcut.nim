import ../native/ffi
import callback

type
  GUIShortcutMode* = enum
    shortSimple
    shortOnce
    shortHold
  GUIShortcutKey* = object
    code*: GUIKeycode
    mods*: GUIKeymods
  GUIShortcut* = ref object
    table: ptr GUIShortcuts
    mode*: GUIShortcutMode
    pressed: bool
    # Shortcut Action
    key: GUIShortcutKey
    cb*: GUICallback
  GUIShortcuts* = object
    list: seq[GUIShortcut]

type
  GUIObserver* = ref object
    table: ptr GUIObservers
    # Observer Action
    watch*: set[GUIEvent]
    cb*: GUICallback
  GUIObservers* = object
    list: seq[GUIObserver]

# ------------------
# Shortcut Key Index
# ------------------

proc hash(key: GUIKeycode, mods: GUIKeymods): uint64 {.inline.} =
  result = cast[uint64](mods) and 0xF
  result = cast[uint64](key) or (result shl 32)

proc hash(short: GUIShortcut): uint64 =
  result = hash(short.key.code, short.key.mods)

# -------------------
# Shortcut Key Sorted
# -------------------

proc idxUpper(table: GUIShortcuts, hash: uint64): int =
  var e = len(table.list)
  # Find Upper Bound
  while result < e:
    let mid = result + (e - result) shr 1
    # Locate to Upper Midpoint
    if table.list[mid].hash <= hash:
      result = mid + 1
    else: e = mid

proc idxLower(table: GUIShortcuts, hash: uint64): int =
  var e = len(table.list)
  # Find Lower Bound
  while result < e:
    let mid = result + (e - result) shr 1
    # Locate to Lower Midpoint
    if table.list[mid].hash < hash:
      result = mid + 1
    else: e = mid

# ---------------------------
# Shortcut Table Manipulation
# ---------------------------

proc insert(table: var GUIShortcuts, short: GUIShortcut) =
  let h = short.hash
  let idx = table.idxUpper(h)
  # Avoid Insert Repeated
  var i = idx - 1
  while i >= 0:
    let s {.cursor.} = table.list[i]
    # Check Repeated
    if s.hash != h: break
    elif s == short: return
    # Next Ocurrence
    dec(i)
  # Insert Shortcut to Table
  table.list.insert(short, idx)

proc remove(table: var GUIShortcuts, short: GUIShortcut) =
  let
    l = len(table.list)
    h = short.hash
  # Avoid Empty Table
  if l == 0: return
  # Ensure is Removed
  var idx = table.idxLower(h)
  while idx < l:
    let s {.cursor.} = table.list[idx]
    # Remove if was Found
    if s.hash != h: break
    elif s == short:
      table.list.delete(idx)
      return
    # Next Index
    inc(idx)

# --------------------------
# Shortcut Callback Creation
# --------------------------

proc shortcut*(cb: GUICallback, key: GUIShortcutKey): GUIShortcut =
  new result
  # Initial Key and Callback
  result.key = key
  result.cb = cb

proc shortcut*(cb: GUICallback): GUIShortcut =
  new result
  # Initial Callback
  result.cb = cb

# ---------------------
# Shortcut Key Creation
# ---------------------

converter key*(code: GUIKeycode): GUIShortcutKey =
  result.code = code

proc `+`*(code: GUIKeycode, mods: GUIKeymods): GUIShortcutKey =
  result.mods = mods
  result.code = code

# --------------------
# Shortcut Key Binding
# --------------------

proc key*(short: GUIShortcut): GUIShortcutKey {.inline.} =
  short.key # Pass by Copy

proc `key=`*(short: GUIShortcut, key: GUIShortcutKey) =
  let table = short.table
  if isNil(table):
    short.key = key
    return
  # Rebind Shortcut
  table[].remove(short)
  short.key = key
  table[].insert(short)

# -----------------------
# Shortcut Table Register
# -----------------------

proc register*(table: var GUIShortcuts, short: GUIShortcut) =
  assert isNil(short.table)
  short.table = addr table
  # Insert Shortcut to Table
  table.insert(short)

proc unregister*(short: GUIShortcut) =
  let table = short.table
  assert not isNil(table)
  # Remove Shortcut from Table
  table[].remove(short)
  short.table = nil

# --------------------------
# Observer Callback Creation
# --------------------------

proc observer*(cb: GUICallback, watch: set[GUIEvent]): GUIObserver =
  new result
  # Initial Callback
  result.cb = cb
  result.watch = watch

proc observer*(cb: GUICallback): GUIObserver =
  new result
  # Initial Callback
  result.cb = cb

# -----------------------
# Observer Table Register
# -----------------------

proc register*(table: var GUIObservers, obs: GUIObserver) =
  assert isNil(obs.table)
  obs.table = addr table
  # Insert Observer
  table.list.add(obs)

proc unregister*(obs: GUIObserver) =
  let table = obs.table
  assert not isNil(table)
  # Remove Observer from Table
  let idx = table.list.find(obs)
  table.list.del(idx)
  obs.table = nil

# -----------------------
# Shortcut Table Dispatch
# -----------------------

proc dispatch(short: GUIShortcut, state: ptr GUIState) =
  let
    pressed = state.kind in {evKeyDown, evFocusNext}
    delta = pressed xor short.pressed
  # Check Dispatch Mode
  let check = case short.mode
  of shortSimple: pressed
  of shortOnce: pressed and delta
  of shortHold: delta
  # Dispatch Callback
  if check: force(short.cb)
  short.pressed = pressed

proc dispatch*(table: var GUIShortcuts, state: ptr GUIState) =
  let
    l = len(table.list)
    h = hash(state.key, state.mods)
  var idx = table.idxLower(h)
  # Dispatch Callbacks from Key Combination
  while idx < l:
    let s {.cursor.} = table.list[idx]
    if s.hash != h: break
    # Dispatch Callback
    s.dispatch(state)
    inc(idx)

# -----------------------
# Observer Table Dispatch
# -----------------------

proc dispatch*(table: var GUIObservers, state: ptr GUIState) =
  for obs in table.list:
    # Dispatch Observer if is Activated
    if state.kind in obs.watch:
      force(obs.cb)
