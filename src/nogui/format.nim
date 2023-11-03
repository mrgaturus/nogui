# ------------------
# Variadic Arguments
# ------------------

{.push header: "<stdarg.h>".}
type va_list {.importc: "va_list".} = object
proc va_start(v: va_list) {.importc: "va_start", varargs.}
proc va_end(v: va_list) {.importc: "va_end".}
{.pop.}

proc v_snprintf(s: cstring, n: cint, format: cstring, arg: va_list): cint 
  {.importc: "vsnprintf", header: "<stdio.h>", noSideEffect.}

# ----------------------
# Shallow String Copying
# ----------------------

type 
  CacheString* = object
    s: string
  # Avoids Implicits Copies
  ShallowString* = ptr CacheString

converter peek*(c: ShallowString): string =
  copyMem(addr result, pointer c, sizeof string)

# ------------------------
# Alloc-Less String Format
# ------------------------

proc format*(c: ShallowString, f: cstring): string {.varargs.} =
  var s = c.peek()
  let l0 = cast[cint](s.len)
  # Auxiluar Values
  var
    l: cint
    b = cstring s
    args: va_list
  # Try First Format
  va_start(args, f)
  l = v_snprintf(b, l0, f, args) + 1
  va_end(args)
  # Needs Expand?
  if l0 != l:
    setLen(s, l)
    b = cstring s
    # Try Second Format
    va_start(args, f)
    l = v_snprintf(b, l, f, args)
    va_end(args)
  # Move String
  c.s = move s
  c.peek()
