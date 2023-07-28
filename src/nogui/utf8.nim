# Up to 0xFFFF, No Emojis, Sorry

type
  UTF8Input* = object
    str: string
    cursor: int32
    # Last Widget Used
    used: pointer
  # Mapping Without Weirdness
  UTF8Unsafe = ptr UncheckedArray[uint8]

{.push boundChecks: off.}
proc toUnsafe(input: ptr UTF8Input): ptr UncheckedArray[uint8] {.inline.} =
  # Convert to Unsafe Array
  cast[UTF8Unsafe](addr input.str[0])
{.pop.}

# -------------------
# UINT16 RUNE DECODER
# -------------------

template rune16*(str: string, i: int32, rune: uint16) =
  let char0 = uint16 str[i]
  if char0 <= 127:
    rune = char0
    inc(i, 1) # Move 1 Byte
  elif char0 shr 5 == 0b110:
    let char1 = uint16 str[i + 1]
    rune = # Use 2 bytes
      (char0 and 0x1f) shl 6 or
      (char1 and 0x3f)
    inc(i, 2) # Move 2 Bytes
  elif char0 shr 4 == 0b1110:
    let 
      char1 = uint16 str[i + 1]
      char2 = uint16 str[i + 2]
    rune = # Use 3 bytes
      (char0 and 0xf) shl 12 or
      (char1 and 0x3f) shl 6 or
      (char2 and 0x3f)
    inc(i, 3) # Move 3 bytes
  else: # Invalid UTF8
    rune = char0
    inc(i, 1) # Move 1 byte

iterator runes16*(str: string): uint16 =
  var # 2GB str?
    i: int32
    result: uint16
  while i < len(str):
    rune16(str, i, result)
    yield result # Return Rune

# ------------------------
# UTF8 Current Manipulator
# ------------------------

proc check*(input: ptr UTF8Input, user: pointer): bool =
  result = input.used == user

proc current*(input: ptr UTF8Input, user: pointer) =
  # Reset Cursor if not same
  if input.used != user:
    input.cursor = 0
  # Change Input User
  input.used = user

# ------------------------------
# UTF8 INPUT DIRECT MANIPULATION
# ------------------------------

template `index`*(input: ptr UTF8Input): int32 =
  input.cursor

template `text`*(input: ptr UTF8Input | UTF8Input): string =
  input.str # Returns Current String

proc `text=`*(input: var UTF8Input, str: string) =
  input.str = str
  # Change Last Used
  input.used = nil
  input.cursor = 0

# ----------------------
# Utf8 Cursor Step Procs
# ----------------------

proc jump*(input: ptr UTF8Input, idx: int32) =
  let
    l = int32 len(input.str)
    c = clamp(idx, 0, l)
  # Jump to Desired Position
  input.cursor = c

proc next*(input: ptr UTF8Input) =
  let 
    l = len(input.str)
    str = input.toUnsafe()
  # Iterate to Next UTF8 Character
  var i = input.cursor + 1
  while i < l and (str[i] and 0xC0) == 0x80:
    # Next String Char
    inc(i) 
  if i <= l: 
    input.cursor = i

proc prev*(input: ptr UTF8Input) =
  let str = input.toUnsafe()
  # Iterate to Prev UTF8 Character
  var i = input.cursor - 1
  while i > 0 and (str[i] and 0xC0) == 0x80:
    # Prev String Char
    dec(i)
  if i >= 0:
    input.cursor = i

# -------------------
# Utf8 Deletion Procs
# -------------------

proc backspace*(input: ptr UTF8Input) =
  # Calculate Difference
  let c0 = input.cursor
  input.prev()
  let c1 = input.cursor
  # Check Difference
  let
    delta = c0 - c1
    str = input.toUnsafe()
  # Move String Content to Previous
  if delta > 0:
    let l = len(input.str)      
    if c0 < l:
      copyMem(addr str[c1], addr str[c0], l - c0)
    # Trim String Length
    setLen(input.str, l - delta)

proc delete*(input: ptr UTF8Input) =
  if input.cursor < len(input.str):
    # Delete Next Char
    input.next()
    input.backspace()

# --------------------
# Utf8 Insertion Procs
# --------------------

proc insert*(input: ptr UTF8Input, str: cstring, l: int32) =
  let # Constants
    i = input.cursor
    l0 = len(input.str)
    l1 = l0 + l
  # Expand String
  setLen(input.str, l1)
  let str0 = input.toUnsafe()
  # Free space for new string
  if i < l0:
    moveMem(addr str0[i + l], addr str0[i], l1 - i)
  copyMem(addr str0[i], str, l)
  # Forward Index
  input.cursor += l
