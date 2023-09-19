from ../gui/signal import GUICallback, push, valid

# ------------------------
# Shared Values Definition
# ------------------------

type
  ValueHeader = object
    foreign: bool
    cb*: GUICallback
  ValueData[T] {.union.} = object
    value: T
    loc: pointer
  ValueOpaque = ptr object
    head: ValueHeader
    loc: pointer
  # - Widget Shared Values
  Value*[T] = object
    head*: ValueHeader
    data: ValueData[T]
  SValue*[T] = ptr Value[T]

converter toShared*[T](value: var Value[T]): 
  SValue[T] {.inline.} = addr value

# Shared Values Type Shortcuts
template `@`*(t: typedesc): typedesc = Value[t]
template `&`*(t: typedesc): typedesc = SValue[t]

# ---------------------------
# Shared Values Encapsulation
# ---------------------------

proc value*[T](a: T): Value[T] =
  result.data.value = a

proc value*[T](a: T, cb: GUICallback): Value[T] =
  result.head.cb = cb
  result.data.value = a

proc value*[T](a: ptr T): Value[T] =
  result.head.foreign = true
  result.data.loc = a

proc value*[T](a: ptr T, cb: GUICallback): Value[T] =
  let head = addr result.head
  head.foreign = true
  head.cb = cb
  # Store Foreign Value
  result.data.loc = a

# ------------------------
# Shared Values Reactivity
# ------------------------

proc peek(head: var ValueHeader): pointer =
  result = addr cast[ValueOpaque](addr head).loc
  # De-reference as Foreign Pointer
  if head.foreign:
    result = cast[ptr pointer](result)[]

proc react(head: var ValueHeader): pointer =
  result = head.peek()
  # Queue Changed Callback
  if valid(head.cb):
    push(head.cb)

# -------------------------
# Shared Values Abstraction
# -------------------------

template peek*[T](value: SValue[T]): ptr T =
  cast[ptr T](peek value.head)

template react*[T](value: SValue[T]): ptr T =
  cast[ptr T](react value.head)
