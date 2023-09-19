from ../gui/signal import GUICallback, push, valid

# ------------------------
# Shared Values Definition
# ------------------------

type
  ValueHeader = object
    cb*: GUICallback
    loc: pointer
  ValueOpaque = ptr object
    head: ValueHeader
    loc: pointer
  # - Widget Shared Values
  Value*[T] = object
    head*: ValueHeader
    data: T
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
  result.data = a

proc value*[T](a: T, cb: GUICallback): Value[T] =
  result.data = a
  result.head.cb = cb

proc value*[T](a: ptr T): Value[T] =
  result.head.loc = a

proc value*[T](a: ptr T, cb: GUICallback): Value[T] =
  let head = addr result.head
  # Set Foreign Data
  head.loc = a
  head.cb = cb

# ------------------------
# Shared Values Reactivity
# ------------------------

proc peek(head: var ValueHeader): pointer =
  # Decide Value Location
  if isNil(head.loc):
    addr cast[ValueOpaque](addr head).loc
  else: cast[ptr pointer](head.loc)

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
